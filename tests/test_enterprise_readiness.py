"""Verify multi-environment readiness, Day-2 controls, and Terraform safety rules."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent


class EnterpriseReadinessTest(unittest.TestCase):
    """Validate multi-environment, security, FinOps, Dataform, Dataplex, and CI controls."""

    def test_no_non_short_circuit_trimspace_in_terraform(self) -> None:
        bad_trim = re.compile(r'var\.[A-Za-z0-9_]+\s*!=\s*null\s*&&\s*trimspace\(')
        skip_dirs = {".git", ".terraform", "__pycache__", ".pytest_cache"}
        for tf_path in sorted(REPO_ROOT.rglob("*.tf")):
            if any(part in skip_dirs for part in tf_path.parts):
                continue
            rel = str(tf_path.relative_to(REPO_ROOT))
            text = tf_path.read_text(encoding="utf-8")
            with self.subTest(file=rel):
                self.assertIsNone(
                    bad_trim.search(text),
                    f"Unsafe null && trimspace pattern in {rel}",
                )

    def test_gitignore_tracks_lockfiles(self) -> None:
        gitignore = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertNotIn(".terraform.lock.hcl", gitignore)
        makefile = (REPO_ROOT / "Makefile").read_text(encoding="utf-8")
        self.assertNotIn("-name \".terraform.lock.hcl\"", makefile)
        self.assertIn("ENV ?= dev", makefile)
        self.assertIn("TFSTATE_BUCKET ?=", makefile)
        self.assertIn("export ENV TFSTATE_BUCKET STAGE VAR_FILE", makefile)
        self.assertIn('-backend-config="bucket=$$TFSTATE_BUCKET"', makefile)
        self.assertIn('-backend-config="prefix=$$STAGE/$$ENV"', makefile)

    def test_multi_env_folder_hierarchy_and_stage_resolution(self) -> None:
        fh_main = (REPO_ROOT / "modules" / "foundation" / "folder-hierarchy" / "main.tf").read_text(encoding="utf-8")
        fh_out = (REPO_ROOT / "modules" / "foundation" / "folder-hierarchy" / "outputs.tf").read_text(encoding="utf-8")
        self.assertIn('"02-environments"', fh_main)
        for out_name in (
            "environment_folder_ids",
            "environment_data_platform_folder_ids",
            "environment_storage_folder_ids",
            "environment_compute_folder_ids",
            "storage_folder_id",
            "compute_folder_id",
        ):
            self.assertIn(f'output "{out_name}"', fh_out)

        org_out = (REPO_ROOT / "foundation" / "01-org-governance" / "outputs.tf").read_text(encoding="utf-8")
        for out_name in (
            "environment_folder_ids",
            "environment_data_platform_folder_ids",
            "environment_storage_folder_ids",
            "environment_compute_folder_ids",
            "storage_folder_id",
            "compute_folder_id",
            "audit_project_lien_name",
        ):
            self.assertIn(f'output "{out_name}"', org_out)

        net_vars = (REPO_ROOT / "foundation" / "02-security-network" / "variables.tf").read_text(encoding="utf-8")
        self.assertIn('variable "environment_folder_ids"', net_vars)
        plat_vars = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "variables.tf").read_text(encoding="utf-8")
        self.assertIn('variable "environment_storage_folder_ids"', plat_vars)
        self.assertIn('variable "environment_compute_folder_ids"', plat_vars)

    def test_envs_templates_enforce_posture(self) -> None:
        net_dev = (REPO_ROOT / "foundation" / "02-security-network" / "envs" / "dev.tfvars.example").read_text(encoding="utf-8")
        net_prod = (REPO_ROOT / "foundation" / "02-security-network" / "envs" / "prod.tfvars.example").read_text(encoding="utf-8")
        self.assertIn('environment             = "dev"', net_dev)
        self.assertIn("enforce_vpc_sc          = false", net_dev)
        self.assertIn('environment             = "prod"', net_prod)
        self.assertIn("enforce_vpc_sc          = true", net_prod)

        plat_dev = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "envs" / "dev.tfvars.example").read_text(encoding="utf-8")
        plat_prod = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "envs" / "prod.tfvars.example").read_text(encoding="utf-8")
        self.assertIn("deletion_protection        = false", plat_dev)
        self.assertIn("baseline_slots             = 0", plat_dev)
        self.assertIn("max_slots                  = 100", plat_dev)
        self.assertIn("deletion_protection        = true", plat_prod)
        self.assertIn("baseline_slots       = 0", plat_prod)
        self.assertIn("etl_baseline_slots   = 0", plat_prod)
        self.assertIn("bi_baseline_slots    = 0", plat_prod)
        self.assertIn("adhoc_baseline_slots = 0", plat_prod)
        self.assertIn("$5,365.50/mo", plat_prod)
        self.assertIn("enforce_vpc_sc             = true", plat_prod)
        self.assertIn("immutable_image_tags       = true", plat_prod)

        gov_dev = (REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / "envs" / "dev.tfvars.example").read_text(encoding="utf-8")
        self.assertIn("enable_scheduled_workflow    = false", gov_dev)

    def test_link_stages_multi_source_export_gcs_and_env_flag(self) -> None:
        script_path = REPO_ROOT / "scripts" / "link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            gcs_store = tmp_path / "gcs_store"
            src_a = tmp_path / "stage_a"
            src_b = tmp_path / "stage_b"
            dst = tmp_path / "stage_dst"
            for d in (bin_dir, gcs_store, src_a, src_b, dst):
                d.mkdir()

            (dst / "variables.tf").write_text(
                'variable "environment" {\n  type = string\n}\n'
                'variable "kms_key_id" {\n  type = string\n}\n'
                'variable "vpc_id" {\n  type = string\n}\n',
                encoding="utf-8",
            )

            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json, sys\n"
                "arg = next(a for a in sys.argv[1:] if a.startswith('-chdir='))\n"
                "src = arg.split('=', 1)[1]\n"
                "if src.endswith('stage_a'):\n"
                "    print(json.dumps({'kms_key_id': {'value': 'k1'}}))\n"
                "else:\n"
                "    print(json.dumps({'vpc_id': {'value': 'v2'}}))\n",
                encoding="utf-8",
            )
            tf_shim.chmod(0o755)

            gcloud_shim = bin_dir / "gcloud"
            gcloud_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import os, shutil, sys\n"
                "from pathlib import Path\n"
                "store = Path(os.environ['TEST_GCS_STORE'])\n"
                "args = sys.argv[1:]\n"
                "if args[1] == 'cp':\n"
                "    target = store / args[3].removeprefix('gs://')\n"
                "    target.parent.mkdir(parents=True, exist_ok=True)\n"
                "    shutil.copyfile(args[2], target)\n"
                "elif args[1] == 'cat':\n"
                "    sys.stdout.write((store / args[2].removeprefix('gs://')).read_text(encoding='utf-8'))\n",
                encoding="utf-8",
            )
            gcloud_shim.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["TEST_GCS_STORE"] = str(gcs_store)

            res = subprocess.run(
                [str(script_path), "--env", "staging", "--export-gcs", "gs://b/merged.json", str(src_a), str(src_b)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            exported = json.loads((gcs_store / "b" / "staging" / "merged.json").read_text(encoding="utf-8"))
            self.assertEqual(exported, {"environment": "staging", "kms_key_id": "k1", "vpc_id": "v2"})

            res2 = subprocess.run(
                [str(script_path), "--env", "staging", "--from-gcs", "gs://b/merged.json", str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res2.returncode, 0, res2.stderr)
            linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
            self.assertEqual(linked, {"environment": "staging", "kms_key_id": "k1", "vpc_id": "v2"})

            for raw_uri, expected_rel in (
                ("gs://b", Path("b/dev/foundation-outputs.json")),
                ("gs://b/foundation-outputs.json", Path("b/dev/foundation-outputs.json")),
                ("gs://b/dev/foundation-outputs.json", Path("b/dev/foundation-outputs.json")),
                ("gs://b/foundation-dev.json", Path("b/foundation-dev.json")),
            ):
                with self.subTest(uri=raw_uri):
                    exp_res = subprocess.run(
                        [str(script_path), "--env", "dev", "--export-gcs", raw_uri, str(src_a), str(src_b)],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(exp_res.returncode, 0, exp_res.stderr)
                    self.assertTrue((gcs_store / expected_rel).is_file(), f"Missing {expected_rel}")
                    from_res = subprocess.run(
                        [str(script_path), "--env", "dev", "--from-gcs", raw_uri, str(dst)],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(from_res.returncode, 0, from_res.stderr)
                    self.assertEqual(
                        json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8")),
                        {"environment": "dev", "kms_key_id": "k1", "vpc_id": "v2"},
                    )

            # Verify --tfstate-bucket validation rejects empty/flag-swallowing values with exit code 2.
            for bad_bucket_args in (
                ["--env", "staging", "--tfstate-bucket", "", str(src_a), str(dst)],
                ["--env", "staging", "--tfstate-bucket", "--env", str(src_a), str(dst)],
                ["--env", "staging", "--tfstate-bucket=", str(src_a), str(dst)],
                ["--env", "staging", "--tfstate-bucket", "BAD_BUCKET", str(src_a), str(dst)],
            ):
                with self.subTest(bad_bucket_args=bad_bucket_args):
                    bad_res = subprocess.run(
                        [str(script_path), *bad_bucket_args],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(bad_res.returncode, 2, bad_res.stderr)

            # Verify fail-closed cross-env state mismatch guard in both local-link and --export-gcs modes.
            mismatch_src = tmp_path / "mismatch_stage"
            mismatch_src.mkdir()
            mismatch_tf = bin_dir / "terraform"
            mismatch_tf.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({'environment': {'value': 'dev', 'sensitive': False}, 'kms_key_id': {'value': 'k-dev'}}))\n",
                encoding="utf-8",
            )
            mismatch_tf.chmod(0o755)
            for mismatch_args in (
                ["--env", "staging", str(mismatch_src), str(dst)],
                ["--env", "staging", "--export-gcs", "gs://b/merged.json", str(mismatch_src)],
            ):
                with self.subTest(mismatch_args=mismatch_args):
                    mm_res = subprocess.run(
                        [str(script_path), *mismatch_args],
                        env=env,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(mm_res.returncode, 1, mm_res.stderr)
                    self.assertIn("ERROR:", mm_res.stderr)
                    self.assertIn("environment='dev'", mm_res.stderr)
                    self.assertIn("expected 'staging'", mm_res.stderr)

            # Verify --tfstate-bucket + --env re-initializes multi-env stage (with envs/) before output -json.
            multi_src = tmp_path / "foundation" / "02-security-network"
            (multi_src / "envs").mkdir(parents=True)
            call_log = tmp_path / "tf_calls.log"
            init_tf = bin_dir / "terraform"
            init_tf.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "args = sys.argv[1:]\n"
                "with open(os.environ['TF_CALL_LOG'], 'a', encoding='utf-8') as f:\n"
                "    f.write(' '.join(args) + '\\n')\n"
                "if 'output' in args:\n"
                "    print(json.dumps({'environment': {'value': 'staging', 'sensitive': False}, 'vpc_id': {'value': 'v-stg'}}))\n",
                encoding="utf-8",
            )
            init_tf.chmod(0o755)
            init_env = env.copy()
            init_env["TF_CALL_LOG"] = str(call_log)
            init_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "staging",
                    "--tfstate-bucket",
                    "my-tfstate-bucket",
                    "foundation/02-security-network",
                    str(dst),
                ],
                cwd=tmp_path,
                env=init_env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(init_res.returncode, 0, init_res.stderr)
            tf_calls = call_log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(tf_calls), 2)
            self.assertIn("init -reconfigure -input=false", tf_calls[0])
            self.assertIn("-backend-config=bucket=my-tfstate-bucket", tf_calls[0])
            self.assertIn("-backend-config=prefix=foundation/02-security-network/staging", tf_calls[0])
            self.assertIn("output -json", tf_calls[1])

    def test_vpc_sc_additive_resources_and_non_lockout(self) -> None:
        net_sec = (REPO_ROOT / "modules" / "foundation" / "network-security" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("_${var.environment}_data_perimeter", net_sec)
        self.assertIn("vpc_accessible_services", net_sec)
        self.assertIn("google_access_context_manager_access_level", net_sec)
        self.assertIn("ignore_changes", net_sec)
        for svc in ("bigquery.googleapis.com", "run.googleapis.com", "workflows.googleapis.com", "datastream.googleapis.com"):
            self.assertIn(f'"{svc}"', net_sec)
        for unsupported in ("bigquerystorage.googleapis.com", "bigqueryreservation.googleapis.com", "workflowexecutions.googleapis.com"):
            self.assertNotIn(f'"{unsupported}"', net_sec)
        self.assertIn("method_selectors", net_sec)

        plat_main = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("google_access_context_manager_service_perimeter_dry_run_resource", plat_main)
        self.assertIn("google_access_context_manager_service_perimeter_resource", plat_main)
        self.assertIn("google_access_context_manager_service_perimeter_dry_run_ingress_policy", plat_main)
        self.assertIn("google_access_context_manager_service_perimeter_ingress_policy", plat_main)

        gov_main = (REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("google_access_context_manager_service_perimeter_dry_run_ingress_policy", gov_main)
        self.assertIn("google_access_context_manager_service_perimeter_ingress_policy", gov_main)

    def test_dataplex_quality_scan_and_monitoring_alerts(self) -> None:
        dp_main = (REPO_ROOT / "modules" / "data" / "dataplex-scans" / "main.tf").read_text(encoding="utf-8")
        dp_out = (REPO_ROOT / "modules" / "data" / "dataplex-scans" / "outputs.tf").read_text(encoding="utf-8")
        self.assertIn("data_quality_spec", dp_main)
        self.assertIn('row_filter       = "order_date >= DATE(\'1970-01-01\')"', dp_main)
        self.assertIn('sql_statement = "SELECT order_id, order_date FROM $${data()} WHERE order_date > CURRENT_DATE()"', dp_main)
        for tok in ("order_id", "order_status", "gross_amount", "net_amount", "customer_email", "sql_assertion", "CURRENT_DATE()"):
            self.assertIn(tok, dp_main)
        self.assertIn('output "quality_scan_id"', dp_out)
        self.assertIn('output "dataplex_quality_scan_id"', dp_out)

        for root in ("data/sandbox", "data/enterprise/02-governance-ops"):
            outs = (REPO_ROOT / root / "outputs.tf").read_text(encoding="utf-8")
            self.assertIn('output "quality_scan_id"', outs)
            self.assertIn('output "dataplex_quality_scan_id"', outs)
            main_text = (REPO_ROOT / root / "main.tf").read_text(encoding="utf-8")
            self.assertIn('resource "google_bigquery_table" "fct_orders_seed"', main_text)
            self.assertIn("require_partition_filter = true", main_text)
            self.assertIn('clustering               = ["customer_id", "currency_code"]', main_text)
            self.assertIn("ignore_changes = [schema, description, labels]", main_text)
            self.assertIn('resource "google_project_iam_member" "dataplex_agent_job_user"', main_text)
            for col in ('"order_status"', '"customer_email"', '"tax_amount"', '"_cdc_sequence_num"', '"_op_type"'):
                self.assertIn(col, main_text)
            cdc_section = main_text.split('resource "google_bigquery_table" "fct_orders_seed"', 1)[0]
            self.assertNotIn('name        = "status"', cdc_section)
            self.assertNotIn('name        = "updated_at"', cdc_section)

        mon_main = (REPO_ROOT / "modules" / "foundation" / "monitoring-alerts" / "main.tf").read_text(encoding="utf-8")
        for metric in (
            "pubsub.googleapis.com/subscription/num_undelivered_messages",
            "workflows.googleapis.com/finished_execution_count",
            "run.googleapis.com/job/completed_execution_count",
            "bigquery.googleapis.com/slots/allocated_for_project",
            "dataform.googleapis.com",
        ):
            self.assertIn(metric, mon_main)
        sec_outs = (REPO_ROOT / "foundation" / "02-security-network" / "outputs.tf").read_text(encoding="utf-8")
        self.assertIn('output "notification_channel_ids"', sec_outs)

    def test_custom_dataform_role_and_cron_alignment(self) -> None:
        for path in (
            REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf",
            REPO_ROOT / "data" / "sandbox" / "main.tf",
        ):
            text = path.read_text(encoding="utf-8")
            self.assertIn("dataform_pipeline_runner", text)
            self.assertIn('"bigquery.tables.setCategory"', text)
            self.assertNotIn('"bigquery.datasets.update"', text)
            self.assertNotIn('"bigquery.datasets.delete"', text)

        for path in (
            REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / "main.tf",
            REPO_ROOT / "data" / "sandbox" / "main.tf",
        ):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("roles/bigquery.dataOwner", text)

        gov_vars = (REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / "variables.tf").read_text(encoding="utf-8")
        self.assertRegex(gov_vars, r'variable\s+"enable_scheduled_workflow"[\s\S]*?default\s*=\s*false')

        df_main = (REPO_ROOT / "modules" / "data" / "dataform-repository" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("45 1 * * *", df_main)
        self.assertIn("${var.environment}-main", df_main)
        self.assertIn("${var.environment}-daily", df_main)
        self.assertIn("pii_masked_policy_tag", df_main)
        self.assertIn("pii_restricted_policy_tag", df_main)

    def test_finops_quarantine_audit_lien_and_partitioning(self) -> None:
        org_vars = (REPO_ROOT / "foundation" / "01-org-governance" / "variables.tf").read_text(encoding="utf-8")
        org_main = (REPO_ROOT / "foundation" / "01-org-governance" / "main.tf").read_text(encoding="utf-8")
        self.assertRegex(org_vars, r'variable\s+"lock_audit_bucket"[\s\S]*?default\s*=\s*true')
        self.assertRegex(org_vars, r'variable\s+"enable_audit_project_lien"[\s\S]*?default\s*=\s*true')
        self.assertIn('resource "google_resource_manager_lien" "audit_project"', org_main)
        self.assertIn('resource "google_tags_tag_binding" "audit_finops"', org_main)

        for path in (
            REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf",
            REPO_ROOT / "data" / "sandbox" / "main.tf",
        ):
            text = path.read_text(encoding="utf-8")
            self.assertIn('matches_prefix = ["incoming/"]', text)
            self.assertIn("google_artifact_registry_repository", text)

        bq_vars = (REPO_ROOT / "modules" / "data" / "bigquery-dataset" / "variables.tf").read_text(encoding="utf-8")
        self.assertRegex(bq_vars, r'variable\s+"max_time_travel_hours"[\s\S]*?default\s*=\s*168')

        for path in (
            REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / "main.tf",
            REPO_ROOT / "data" / "sandbox" / "main.tf",
        ):
            text = path.read_text(encoding="utf-8")
            self.assertIn('field = "order_date"', text)
            self.assertIn('field = "_ingested_at"', text)

        res_main = (REPO_ROOT / "modules" / "data" / "bigquery-reservations" / "main.tf").read_text(encoding="utf-8")
        self.assertIn('"adhoc"', res_main)

    def test_gitops_workflow_skill_and_decommission_docs(self) -> None:
        deploy_wf = (REPO_ROOT / ".github" / "workflows" / "terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("id-token: write", deploy_wf)
        self.assertIn("vars.GCP_WIF_PROVIDER", deploy_wf)
        self.assertIn("vars.GCP_WIF_SERVICE_ACCOUNT || vars.GCP_TF_SA_EMAIL", deploy_wf)
        self.assertRegex(deploy_wf, r"google-github-actions/auth@[0-9a-f]{40}")
        self.assertNotIn("type: string", deploy_wf)
        for block in deploy_wf.split("run: |")[1:]:
            run_body = block.split("\n      - name:", 1)[0].split("\n  deploy-", 1)[0]
            self.assertNotIn("${{", run_body)

        skill = (REPO_ROOT / ".agents" / "skills" / "setup-customer-foundation" / "SKILL.md").read_text(encoding="utf-8")
        self.assertNotIn('--replication-policy="automatic"', skill)
        self.assertIn('--replication-policy="user-managed"', skill)
        self.assertIn('--locations="${REGION}"', skill)

        decomm_doc = REPO_ROOT / "docs" / "04-multi-env-and-decommission.md"
        self.assertTrue(decomm_doc.is_file())
        decomm_text = decomm_doc.read_text(encoding="utf-8")
        self.assertIn("resource-manager liens", decomm_text)
        self.assertIn("state rm", decomm_text)

    def test_questionnaire_and_launchpad_handoff(self) -> None:
        questionnaire_path = REPO_ROOT / "QUESTIONNAIRE.md"
        self.assertTrue(questionnaire_path.is_file(), "Missing QUESTIONNAIRE.md")
        questionnaire_text = questionnaire_path.read_text(encoding="utf-8")

        for token in (
            "retention_days",
            "2555",
            "lock_audit_bucket",
            "kms_protection_level",
            "scc_tier",
            "enforce_vpc_sc",
            "platform-context.json",
            "https://github.com/choo737/gcp-launchpad",
        ):
            with self.subTest(token=token):
                self.assertIn(token, questionnaire_text)

        for rel in (
            "README.md",
            "AGENTS.md",
            "CLAUDE.md",
            ".agents/skills/setup-customer-foundation/SKILL.md",
        ):
            doc_text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            with self.subTest(doc=rel):
                self.assertIn("QUESTIONNAIRE.md", doc_text)
                self.assertIn("platform-context.json", doc_text)
                self.assertIn("https://github.com/choo737/gcp-launchpad", doc_text)

        gitignore_text = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8")
        for entry in ("platform-context.json", ".cm_project", ".codemender/"):
            with self.subTest(gitignore_entry=entry):
                self.assertIn(entry, gitignore_text)

    def test_canonical_readme_codeowners_and_operationalization_guide(self) -> None:
        codeowners = REPO_ROOT / "CODEOWNERS"
        self.assertTrue(codeowners.is_file(), "Missing CODEOWNERS")
        co_text = codeowners.read_text(encoding="utf-8")
        self.assertIn("* @choo737", co_text)
        for path_rule in ("foundation/", "data/", "modules/foundation/", "modules/data/", ".github/workflows/"):
            self.assertIn(path_rule, co_text)

        guide = REPO_ROOT / "docs" / "05-enterprise-operationalization-guide.md"
        self.assertTrue(guide.is_file(), "Missing docs/05-enterprise-operationalization-guide.md")
        guide_text = guide.read_text(encoding="utf-8")
        for marker in (
            "flowchart LR",
            "00-bootstrap",
            "01-org-governance",
            "02-security-network",
            "01-platform",
            "02-governance-ops",
            "additional_quality_scans",
            "--export-gcs",
            "gcp-data-ingestion",
        ):
            self.assertIn(marker, guide_text)

        readme_text = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        self.assertTrue(readme_text.startswith("# GCP Foundation\n"))
        h2_headings = [line for line in readme_text.splitlines() if line.startswith("## ")]
        expected_headings = [
            "## Template Suite Overview",
            "## Create Your Private Repository (Do Not Fork Publicly)",
            "## Architecture & Capabilities",
            "## 6-Step Enterprise Operationalization",
            "## AI Coding Agent Quickstart",
            "## CI/CD Workflows",
            "## Repository Layout",
            "## Quick Verification",
            "## Documentation Index",
            "## License",
        ]
        self.assertEqual(h2_headings, expected_headings)

        for skill_name in (
            "setup-customer-foundation",
            "choose-entry-point",
            "add-data-domain",
            "add-workload-pillar",
            "drift-safe-apply",
        ):
            self.assertIn(skill_name, readme_text)

    def test_day2_multi_domain_wiring_and_additional_quality_scans(self) -> None:
        gov_dir = REPO_ROOT / "data" / "enterprise" / "02-governance-ops"
        gov_main = (gov_dir / "main.tf").read_text(encoding="utf-8")
        gov_vars = (gov_dir / "variables.tf").read_text(encoding="utf-8")
        gov_outs = (gov_dir / "outputs.tf").read_text(encoding="utf-8")

        self.assertIn('data "google_project" "domains"', gov_main)
        self.assertIn("for_each = var.domain_storage_project_ids", gov_main)
        self.assertIn("data.google_project.domains", gov_main)
        self.assertIn("domain_compilation_vars", gov_main)
        self.assertIn("gold_${d}_project", gov_main)
        self.assertIn("gold_${d}_dataset", gov_main)
        self.assertIn("gold_retail_project", gov_main)
        self.assertIn("gold_retail_dataset", gov_main)
        self.assertIn('variable "additional_quality_scans"', gov_vars)
        self.assertIn('module "additional_quality_scans"', gov_main)
        self.assertIn("for_each = var.additional_quality_scans", gov_main)
        self.assertIn('output "additional_quality_scan_ids"', gov_outs)


    def test_workflows_have_no_expression_interpolation_in_run_blocks(self) -> None:
        workflow_files = sorted((REPO_ROOT / ".github" / "workflows").glob("*.yml"))
        self.assertGreaterEqual(len(workflow_files), 1)
        for wf_path in workflow_files:
            wf_text = wf_path.read_text(encoding="utf-8")
            in_run_block = False
            run_indent = 0
            for line_no, raw_line in enumerate(wf_text.splitlines(), start=1):
                stripped = raw_line.lstrip()
                indent = len(raw_line) - len(stripped)
                if in_run_block:
                    if stripped and indent <= run_indent:
                        in_run_block = False
                    else:
                        self.assertNotIn(
                            "${{",
                            raw_line,
                            f"{wf_path.name}:{line_no}: expression interpolation inside run: block",
                        )
                        continue
                if re.match(r"^(?:-\s*)?run\s*:", stripped):
                    self.assertNotIn(
                        "${{",
                        stripped,
                        f"{wf_path.name}:{line_no}: expression interpolation inside run: line",
                    )
                    if stripped.rstrip().endswith(("|", ">", "|-", ">-")):
                        in_run_block = True
                        run_indent = indent

    def test_decisions_1_to_4_and_residual_ci_doc_controls(self) -> None:
        # Decision 1: 00-bootstrap per_stage SAs, bucket prefix IAM, and WIF environments.
        boot_vars = (REPO_ROOT / "foundation/00-bootstrap/variables.tf").read_text(encoding="utf-8")
        boot_main = (REPO_ROOT / "foundation/00-bootstrap/main.tf").read_text(encoding="utf-8")
        boot_outs = (REPO_ROOT / "foundation/00-bootstrap/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('variable "foundation_sa_mode"', boot_vars)
        for sa_key in ("tf_foundation_ci", "org_gov_ci", "net_sec_ci", "data_plat_ci", "tf_ingestion_ci", "dataform_ci"):
            self.assertIn(f'"{sa_key}"', boot_vars)
        for out_name in ("org_gov_ci_sa_email", "net_sec_ci_sa_email", "data_plat_ci_sa_email"):
            self.assertIn(f'output "{out_name}"', boot_outs)
        self.assertIn('resource "google_storage_bucket_iam_member" "tfstate_scoped_admin"', boot_main)
        self.assertIn('resource.type != \\"storage.googleapis.com/Object\\"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_ingestion_viewer"', boot_main)

        wif_vars = (REPO_ROOT / "modules/foundation/github-wif/variables.tf").read_text(encoding="utf-8")
        wif_main = (REPO_ROOT / "modules/foundation/github-wif/main.tf").read_text(encoding="utf-8")
        self.assertIn("environments       = optional(list(string), [])", wif_vars)
        self.assertIn("attribute.repo_env", wif_main)
        self.assertIn("attribute.repository/${each.value.repository}", wif_main)

        # Decision 2: allowed_cmek_service_agents, manage_kms_iam, manage_vpc_sc.
        net_vars = (REPO_ROOT / "modules/foundation/network-security/variables.tf").read_text(encoding="utf-8")
        net_main = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        sec_vars = (REPO_ROOT / "foundation/02-security-network/variables.tf").read_text(encoding="utf-8")
        self.assertIn('variable "allowed_cmek_service_agents"', net_vars)
        self.assertIn('variable "allowed_cmek_service_agents"', sec_vars)
        self.assertIn('resource "google_kms_crypto_key_iam_member" "upstream_service_agents"', net_main)
        self.assertIn('resource "google_kms_crypto_key_iam_member" "upstream_dr_service_agents"', net_main)

        plat_vars = (REPO_ROOT / "data/enterprise/01-platform/variables.tf").read_text(encoding="utf-8")
        plat_main = (REPO_ROOT / "data/enterprise/01-platform/main.tf").read_text(encoding="utf-8")
        gov_vars = (REPO_ROOT / "data/enterprise/02-governance-ops/variables.tf").read_text(encoding="utf-8")
        gov_main = (REPO_ROOT / "data/enterprise/02-governance-ops/main.tf").read_text(encoding="utf-8")
        gov_outs = (REPO_ROOT / "data/enterprise/02-governance-ops/outputs.tf").read_text(encoding="utf-8")

        for text in (plat_vars, gov_vars):
            self.assertIn('variable "manage_kms_iam"', text)
            self.assertIn('variable "manage_vpc_sc"', text)
        self.assertIn("local.use_cmek && var.manage_kms_iam", plat_main)
        self.assertIn("var.manage_vpc_sc && !var.enforce_vpc_sc", plat_main)
        self.assertIn("local.use_cmek && var.manage_kms_iam", gov_main)
        self.assertIn("var.manage_vpc_sc && !var.enforce_vpc_sc", gov_main)

        # Decision 3: domain_billing_accounts and additional_dataform_repos.
        self.assertIn('variable "domain_billing_accounts"', plat_vars)
        self.assertIn("lookup(var.domain_billing_accounts, each.key, var.billing_account)", plat_main)
        self.assertIn('variable "additional_dataform_repos"', gov_vars)
        self.assertIn('module "additional_dataform_repository"', gov_main)
        self.assertIn("${var.prefix}-${each.key}-medallion", gov_main)
        self.assertIn('output "additional_dataform_repository_names"', gov_outs)

        # Decision 4: cost floor defaults & official GCS dual-region location mapping.
        org_example = (REPO_ROOT / "foundation/01-org-governance/terraform.tfvars.example").read_text(encoding="utf-8")
        self.assertIn("enable_backup_dr                = false", org_example)
        self.assertIn('variable "dual_region_location"', plat_vars)
        for code in ('"AU"', '"CA"', '"IN"', '"IT"', '"DE"', '"EU"', '"US"', '"ASIA"'):
            self.assertIn(code, plat_main)
        self.assertIn("asia-southeast2", plat_main)
        self.assertIn("asia-east2", plat_main)

        # Residual CI & doc fixes.
        deploy_wf = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("- shared", deploy_wf)
        self.assertEqual(deploy_wf.count("google-github-actions/setup-gcloud@"), 4)
        self.assertIn('BACKEND_PREFIX="foundation/01-org-governance/shared"', deploy_wf)
        self.assertIn("IAC_OUTPUTS_BUCKET", deploy_wf)

        guide = (REPO_ROOT / "docs/05-enterprise-operationalization-guide.md").read_text(encoding="utf-8")
        skill = (REPO_ROOT / ".agents/skills/setup-customer-foundation/SKILL.md").read_text(encoding="utf-8")
        decomm = (REPO_ROOT / "docs/04-multi-env-and-decommission.md").read_text(encoding="utf-8")
        self.assertIn("foundation-outputs.json", guide)
        self.assertIn("foundation-outputs.json", skill)
        self.assertIn("shared-vpc associated-projects remove", decomm)
        self.assertIn("shared-vpc disable", decomm)

    def test_gcs_dual_region_location_inference_via_terraform_console(self) -> None:
        import shutil
        tf_bin = shutil.which("terraform")
        if tf_bin is None:
            self.skipTest("terraform binary not installed")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_repo = Path(tmp) / "repo"
            shutil.copytree(REPO_ROOT / "modules", tmp_repo / "modules")
            shutil.copytree(REPO_ROOT / "data", tmp_repo / "data")
            plat_dir = tmp_repo / "data" / "enterprise" / "01-platform"
            versions_path = plat_dir / "versions.tf"
            versions_path.write_text(
                versions_path.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                encoding="utf-8",
            )
            shutil.rmtree(plat_dir / ".terraform", ignore_errors=True)
            cached_providers = REPO_ROOT / "data" / "enterprise" / "01-platform" / ".terraform" / "providers"
            init_cmd = [tf_bin, f"-chdir={plat_dir}", "init", "-input=false"]
            if cached_providers.is_dir():
                init_cmd.append(f"-plugin-dir={cached_providers}")
            init_res = subprocess.run(init_cmd, capture_output=True, text=True, check=False)
            self.assertEqual(init_res.returncode, 0, init_res.stderr)

            cases = (
                ("australia-southeast1", ["australia-southeast1", "australia-southeast2"], "", "AU"),
                ("northamerica-northeast1", ["northamerica-northeast1", "northamerica-northeast2"], "", "CA"),
                ("asia-south1", ["asia-south1", "asia-south2"], "", "IN"),
                ("europe-west8", ["europe-west8", "europe-west12"], "", "IT"),
                ("europe-west3", ["europe-west3", "europe-west10"], "", "DE"),
                ("asia-southeast1", ["asia-southeast1", "asia-east1"], "", "ASIA"),
                ("us-central1", ["us-central1", "us-east1"], "NAM4", "NAM4"),
            )
            tfvars_path = plat_dir / "dual_region_test.auto.tfvars.json"
            for region, dual_locs, explicit_loc, expected in cases:
                with self.subTest(region=region, dual_locs=dual_locs, explicit_loc=explicit_loc):
                    tfvars_path.write_text(
                        json.dumps({
                            "data_folder_id": "folders/123456",
                            "billing_account": "000000-000000-000000",
                            "region": region,
                            "enable_dual_region_gcs": True,
                            "dual_region_data_locations": dual_locs,
                            "dual_region_location": explicit_loc,
                        }),
                        encoding="utf-8",
                    )
                    res = subprocess.run(
                        [tf_bin, f"-chdir={plat_dir}", "console"],
                        input="local.landing_bucket_location\n",
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(res.returncode, 0, res.stderr)
                    self.assertEqual(res.stdout.strip().strip('"'), expected)


if __name__ == "__main__":
    unittest.main()
