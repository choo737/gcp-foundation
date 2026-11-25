"""Verify multi-environment readiness, Day-2 controls, and Terraform safety rules."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import suite_doc_contract  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


class EnterpriseReadinessTest(unittest.TestCase):
    """Validate multi-environment, security, FinOps, Dataform, Knowledge Catalog (formerly Dataplex), and CI controls."""

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
        fh_vars = (REPO_ROOT / "modules" / "foundation" / "folder-hierarchy" / "variables.tf").read_text(encoding="utf-8")
        fh_main = (REPO_ROOT / "modules" / "foundation" / "folder-hierarchy" / "main.tf").read_text(encoding="utf-8")
        fh_out = (REPO_ROOT / "modules" / "foundation" / "folder-hierarchy" / "outputs.tf").read_text(encoding="utf-8")
        self.assertRegex(fh_vars, r'variable\s+"create_data_subfolders"[\s\S]*?default\s*=\s*false')
        self.assertIn('"fldr-coe"', fh_main)
        self.assertIn('"fldr-environments"', fh_main)
        self.assertIn('"fldr-${each.value}"', fh_main)
        self.assertIn('"fldr-${each.value}-data-platform"', fh_main)
        self.assertIn('"fldr-${each.value}-storage"', fh_main)
        self.assertIn('"fldr-${each.value}-compute"', fh_main)
        self.assertIn('"fldr-${each.value}-ai-platform"', fh_main)
        self.assertIn('"fldr-${each.value}-app-platform"', fh_main)
        self.assertIn('"fldr-network"', fh_main)
        plat_main = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf").read_text(encoding="utf-8")
        self.assertIn('"fldr-${var.environment}-storage"', plat_main)
        self.assertIn('"fldr-${var.environment}-compute"', plat_main)
        self.assertIn('resource "google_folder" "network"', fh_main)
        self.assertNotIn('resource "google_folder" "env_network"', fh_main)
        self.assertIn('var.create_data_subfolders ? local.environment_set : toset([])', fh_main)
        self.assertNotIn('resource "google_folder" "root"', fh_main)
        self.assertNotIn('resource "google_folder" "workloads"', fh_main)
        for out_name in (
            "parent_id",
            "root_folder_id",
            "shared_infra_folder_id",
            "coe_folder_id",
            "network_folder_id",
            "environment_folder_ids",
            "environment_data_platform_folder_ids",
            "environment_storage_folder_ids",
            "environment_compute_folder_ids",
            "storage_folder_id",
            "compute_folder_id",
        ):
            self.assertIn(f'output "{out_name}"', fh_out)
        self.assertNotIn('output "workloads_folder_id"', fh_out)
        self.assertNotIn('output "workload_folder_ids"', fh_out)

        org_out = (REPO_ROOT / "foundation" / "01-org-governance" / "outputs.tf").read_text(encoding="utf-8")
        for out_name in (
            "parent_id",
            "root_folder_id",
            "coe_folder_id",
            "network_folder_id",
            "create_data_subfolders",
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
        self.assertIn('variable "network_folder_id"', net_vars)
        self.assertIn('variable "environment_folder_ids"', net_vars)
        plat_vars = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "variables.tf").read_text(encoding="utf-8")
        self.assertIn('variable "environment_data_folder_ids"', plat_vars)
        self.assertIn('variable "environment_storage_folder_ids"', plat_vars)
        self.assertIn('variable "environment_compute_folder_ids"', plat_vars)
        self.assertRegex(plat_vars, r'variable\s+"create_data_subfolders"[\s\S]*?default\s*=\s*false')
        self.assertRegex(plat_vars, r'variable\s+"split_etl_project"[\s\S]*?default\s*=\s*false')

    def test_envs_templates_enforce_posture(self) -> None:
        net_dev = (REPO_ROOT / "foundation" / "02-security-network" / "envs" / "dev.tfvars.example").read_text(encoding="utf-8")
        net_prod = (REPO_ROOT / "foundation" / "02-security-network" / "envs" / "prod.tfvars.example").read_text(encoding="utf-8")
        self.assertIn('environment             = "dev"', net_dev)
        self.assertIn("enforce_vpc_sc          = false", net_dev)
        self.assertIn('environment             = "prod"', net_prod)
        self.assertIn("enforce_vpc_sc          = false", net_prod)
        self.assertIn("# network_folder_id", net_prod)
        self.assertIn("# shared_infra_folder_id", net_prod)
        self.assertIn("# billing_account", net_prod)

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
        self.assertIn("enforce_vpc_sc             = false", plat_prod)
        self.assertIn("immutable_image_tags       = true", plat_prod)
        self.assertNotIn('["asia-southeast1", "asia-southeast2"]', plat_prod)

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
                [str(script_path), "--env", "uat", "--export-gcs", "gs://b/merged.json", str(src_a), str(src_b)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            exported = json.loads((gcs_store / "b" / "uat" / "merged.json").read_text(encoding="utf-8"))
            self.assertEqual(exported, {"environment": "uat", "kms_key_id": "k1", "vpc_id": "v2"})

            res2 = subprocess.run(
                [str(script_path), "--env", "uat", "--from-gcs", "gs://b/merged.json", str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res2.returncode, 0, res2.stderr)
            linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
            self.assertEqual(linked, {"environment": "uat", "kms_key_id": "k1", "vpc_id": "v2"})

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
                ["--env", "uat", "--tfstate-bucket", "", str(src_a), str(dst)],
                ["--env", "uat", "--tfstate-bucket", "--env", str(src_a), str(dst)],
                ["--env", "uat", "--tfstate-bucket=", str(src_a), str(dst)],
                ["--env", "uat", "--tfstate-bucket", "BAD_BUCKET", str(src_a), str(dst)],
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
                ["--env", "uat", str(mismatch_src), str(dst)],
                ["--env", "uat", "--export-gcs", "gs://b/merged.json", str(mismatch_src)],
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
                    self.assertIn("expected 'uat'", mm_res.stderr)

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
                "    print(json.dumps({'environment': {'value': 'uat', 'sensitive': False}, 'vpc_id': {'value': 'v-uat'}}))\n",
                encoding="utf-8",
            )
            init_tf.chmod(0o755)
            init_env = env.copy()
            init_env["TF_CALL_LOG"] = str(call_log)
            init_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "uat",
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
            self.assertIn("-backend-config=prefix=foundation/02-security-network/uat", tf_calls[0])
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
        self.assertIn("DATE_SUB(CURRENT_DATE(), INTERVAL", dp_main)
        self.assertNotIn("1970-01-01", dp_main)
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
        self.assertIn("\n# GCP Foundation\n", readme_text)
        self.assertIn("assets/folder-hierarchy.png", readme_text)
        arch_text = (REPO_ROOT / "docs" / "01-architecture.md").read_text(encoding="utf-8")
        self.assertIn("../assets/folder-hierarchy.png", arch_text)
        self.assertIn("../assets/folder-hierarchy-bu-chargeback.png", arch_text)
        h2_headings = [line.strip() for line in readme_text.splitlines() if line.startswith("## ")]
        self.assertEqual(h2_headings, suite_doc_contract.CANONICAL_README_H2_SECTIONS)
        self.assertEqual(
            suite_doc_contract.validate_repo_suite_contract(REPO_ROOT, "gcp-foundation"),
            [],
        )

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
        self.assertIn('resource "google_storage_bucket_iam_member" "tfstate_scoped_bucket_reader"', boot_main)
        self.assertIn('role   = "roles/storage.legacyBucketReader"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "tfstate_scoped_admin"', boot_main)
        self.assertNotIn("objectListPrefix", boot_main)
        self.assertNotIn('resource.type != \\"storage.googleapis.com/Object\\"', boot_main)
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
        self.assertEqual(deploy_wf.count("google-github-actions/setup-gcloud@"), 5)
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

    def test_pass7_stage_chaining_tier_l_wif_validations_and_iam(self) -> None:
        script_path = REPO_ROOT / "scripts" / "link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            gcs_store = tmp_path / "gcs_store"
            src_shared = tmp_path / "stage_shared"
            dst = tmp_path / "stage_dst"
            for d in (bin_dir, gcs_store, src_shared, dst):
                d.mkdir()

            (dst / "variables.tf").write_text(
                'variable "environment" {\n  type = string\n}\n'
                'variable "data_folder_id" {\n  type = string\n}\n'
                'variable "kms_key_id" {\n  type = string\n}\n'
                'variable "core_storage_project_id" {\n  type = string\n}\n'
                'variable "dataform_repository_name" {\n  type = string\n}\n',
                encoding="utf-8",
            )

            tf_call_log = tmp_path / "tf_calls.log"
            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['TF_CALL_LOG'], 'a', encoding='utf-8') as f:\n"
                "    f.write(' '.join(sys.argv[1:]) + '\\n')\n"
                "print(json.dumps({'data_folder_id': {'value': 'folders/999'}}))\n",
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
            env["TF_CALL_LOG"] = str(tf_call_log)

            # 1) --env shared exports to shared/01-org-governance-outputs.json.
            shared_res = subprocess.run(
                [str(script_path), "--env", "shared", "--export-gcs", "gs://bkt/01-org-governance-outputs.json", str(src_shared)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(shared_res.returncode, 0, shared_res.stderr)
            shared_obj = gcs_store / "bkt" / "shared" / "01-org-governance-outputs.json"
            self.assertTrue(shared_obj.is_file())
            self.assertEqual(
                json.loads(shared_obj.read_text(encoding="utf-8")),
                {"data_folder_id": "folders/999", "environment": "shared"},
            )

            # 2) Seed dev stage JSONs and test --from-gcs preserving shared/ while setting environment='dev'.
            for name, payload in (
                ("02-security-network-outputs.json", {"environment": "dev", "kms_key_id": "k-dev"}),
                ("01-platform-outputs.json", {"environment": "dev", "core_storage_project_id": "core-dev"}),
                ("02-governance-ops-outputs.json", {"environment": "dev", "dataform_repository_name": "df-dev"}),
            ):
                p = gcs_store / "bkt" / "dev" / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(json.dumps(payload), encoding="utf-8")

            from_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "dev",
                    "--from-gcs",
                    "gs://bkt/shared/01-org-governance-outputs.json",
                    "gs://bkt/02-security-network-outputs.json",
                    str(dst),
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(from_res.returncode, 0, from_res.stderr)
            linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
            self.assertEqual(
                linked,
                {"data_folder_id": "folders/999", "environment": "dev", "kms_key_id": "k-dev"},
            )

            # 3) --export-gcs + --from-gcs merges GCS JSONs directly with zero terraform invocations.
            tf_call_log.unlink()
            merge_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "dev",
                    "--export-gcs",
                    "gs://bkt/foundation-outputs.json",
                    "--from-gcs",
                    "gs://bkt/shared/01-org-governance-outputs.json",
                    "gs://bkt/02-security-network-outputs.json",
                    "gs://bkt/01-platform-outputs.json",
                    "gs://bkt/02-governance-ops-outputs.json",
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(merge_res.returncode, 0, merge_res.stderr)
            self.assertFalse(tf_call_log.exists(), "JSON-merge mode must not invoke terraform")
            merged_out = json.loads((gcs_store / "bkt" / "dev" / "foundation-outputs.json").read_text(encoding="utf-8"))
            self.assertEqual(
                merged_out,
                {
                    "core_storage_project_id": "core-dev",
                    "data_folder_id": "folders/999",
                    "dataform_repository_name": "df-dev",
                    "environment": "dev",
                    "kms_key_id": "k-dev",
                },
            )

            # 4) Reverse flag order (--from-gcs before --export-gcs) works identically.
            rev_merge_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "dev",
                    "--from-gcs",
                    "gs://bkt/shared/01-org-governance-outputs.json",
                    "gs://bkt/02-security-network-outputs.json",
                    "--export-gcs",
                    "gs://bkt/reverse-merged.json",
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(rev_merge_res.returncode, 0, rev_merge_res.stderr)
            self.assertEqual(
                json.loads((gcs_store / "bkt" / "dev" / "reverse-merged.json").read_text(encoding="utf-8")),
                {"data_folder_id": "folders/999", "environment": "dev", "kms_key_id": "k-dev"},
            )

            # 5) Invalid --env rejected by ^(shared|dev|uat|prod)$.
            bad_env = subprocess.run(
                [str(script_path), "--env", "qa", "--from-gcs", "gs://bkt/shared/01-org-governance-outputs.json", str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(bad_env.returncode, 0)

            # 6) External stage dir outside repo_root resolves clean backend prefix without '../'.
            ext_repo = tmp_path / "ext_repo"
            ext_stage = ext_repo / "stages" / "enterprise"
            (ext_repo / ".git").mkdir(parents=True)
            (ext_stage / "envs").mkdir(parents=True)
            tf_call_log.unlink(missing_ok=True)
            ext_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "dev",
                    "--tfstate-bucket",
                    "bkt-state",
                    "--export-gcs",
                    "gs://bkt/ext-outputs.json",
                    "../ext_repo/stages/enterprise",
                ],
                cwd=tmp_path / "stage_dst",
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(ext_res.returncode, 0, ext_res.stderr)
            ext_calls = tf_call_log.read_text(encoding="utf-8")
            self.assertIn("-backend-config=prefix=stages/enterprise/dev", ext_calls)
            self.assertNotIn("..", ext_calls)

            # 7) foundation/01-org-governance always uses /shared prefix even under --env dev.
            org_gov_stage = ext_repo / "foundation" / "01-org-governance"
            org_gov_stage.mkdir(parents=True)
            (org_gov_stage / "versions.tf").write_text('terraform {\n  backend "gcs" {}\n}\n', encoding="utf-8")
            tf_call_log.unlink(missing_ok=True)
            org_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "dev",
                    "--tfstate-bucket",
                    "bkt-state",
                    "--export-gcs",
                    "gs://bkt/org-outputs.json",
                    "../ext_repo/foundation/01-org-governance",
                ],
                cwd=tmp_path / "stage_dst",
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(org_res.returncode, 0, org_res.stderr)
            self.assertIn("-backend-config=prefix=foundation/01-org-governance/shared", tf_call_log.read_text(encoding="utf-8"))

        # Bug #1, #2, #3 in terraform-deploy.yml and github-wif/main.tf.
        deploy_wf = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("environment: shared", deploy_wf)
        self.assertIn("vars.GCP_ORG_GOV_WIF_SA", deploy_wf)
        self.assertIn("vars.GCP_NET_SEC_WIF_SA", deploy_wf)
        self.assertIn("vars.GCP_DATA_PLAT_WIF_SA", deploy_wf)
        self.assertIn("inputs.stage == 'data/sandbox'", deploy_wf)
        self.assertIn("inputs.stage == 'data/enterprise/03-data-science'", deploy_wf)
        self.assertNotIn("GCP_DS_WIF_SA", deploy_wf)
        bootstrap_tfvars_ex = (REPO_ROOT / "foundation/00-bootstrap/terraform.tfvars.example").read_text(encoding="utf-8")
        self.assertIn('allowed_environments = ["shared", "dev", "uat", "prod"]', bootstrap_tfvars_ex)
        self.assertNotIn("foundation-outputs.json\" \"${TARGET_STAGE}\" || true", deploy_wf)
        self.assertNotIn("--tfstate-bucket \"${TFSTATE_BUCKET}\" --export-gcs", deploy_wf)
        self.assertIn("shared/01-org-governance-outputs.json", deploy_wf)
        self.assertIn("02-security-network-outputs.json", deploy_wf)
        self.assertIn("01-platform-outputs.json", deploy_wf)
        self.assertIn("02-governance-ops-outputs.json", deploy_wf)
        self.assertIn("03-data-science-outputs.json", deploy_wf)
        self.assertLess(
            deploy_wf.index("- data/enterprise/03-data-science"),
            deploy_wf.index("- data/enterprise/02-governance-ops"),
        )

        wif_main = (REPO_ROOT / "modules/foundation/github-wif/main.tf").read_text(encoding="utf-8")
        self.assertIn("('environment' in assertion && assertion.environment in [${local.env_list_cel}])", wif_main)
        wif_vars = (REPO_ROOT / "modules/foundation/github-wif/variables.tf").read_text(encoding="utf-8")
        boot_vars = (REPO_ROOT / "foundation/00-bootstrap/variables.tf").read_text(encoding="utf-8")
        self.assertRegex(wif_vars, r'variable\s+"allowed_refs"[\s\S]*?default\s*=\s*\["refs/heads/main"\]')
        self.assertRegex(boot_vars, r'variable\s+"allowed_refs"[\s\S]*?default\s*=\s*\["refs/heads/main"\]')

        # Polish #4 & #6: additional_dataform_repos gold overrides & validations + domain_billing_accounts validation.
        gov_vars = (REPO_ROOT / "data/enterprise/02-governance-ops/variables.tf").read_text(encoding="utf-8")
        gov_main = (REPO_ROOT / "data/enterprise/02-governance-ops/main.tf").read_text(encoding="utf-8")
        self.assertIn('gold_project             = optional(string, "")', gov_vars)
        self.assertIn('gold_dataset             = optional(string, "")', gov_vars)
        self.assertIn("trimspace(r.git_url) == \"\" || trimspace(r.git_token_secret_version) != \"\"", gov_vars)
        self.assertIn("trimspace(each.value.gold_project) != \"\" ? trimspace(each.value.gold_project) : var.primary_gold_project_id", gov_main)
        self.assertIn("trimspace(each.value.gold_dataset) != \"\" ? trimspace(each.value.gold_dataset) : var.primary_gold_dataset_id", gov_main)

        plat_vars = (REPO_ROOT / "data/enterprise/01-platform/variables.tf").read_text(encoding="utf-8")
        self.assertRegex(plat_vars, r'variable\s+"domain_billing_accounts"[\s\S]*?validation\s*\{[\s\S]*?trimspace\(v\)\s*!=\s*""')

        # Exercise Terraform variable validations for additional_dataform_repos and domain_billing_accounts.
        import shutil
        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
            with tempfile.TemporaryDirectory() as tmp:
                tmp_repo = Path(tmp) / "repo"
                shutil.copytree(REPO_ROOT / "modules", tmp_repo / "modules")
                shutil.copytree(REPO_ROOT / "data", tmp_repo / "data")

                gov_dir = tmp_repo / "data" / "enterprise" / "02-governance-ops"
                gov_versions = gov_dir / "versions.tf"
                gov_versions.write_text(
                    gov_versions.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                    encoding="utf-8",
                )
                shutil.rmtree(gov_dir / ".terraform", ignore_errors=True)
                gov_cached = REPO_ROOT / "data" / "enterprise" / "02-governance-ops" / ".terraform" / "providers"
                gov_init = [tf_bin, f"-chdir={gov_dir}", "init", "-input=false"]
                if gov_cached.is_dir():
                    gov_init.append(f"-plugin-dir={gov_cached}")
                self.assertEqual(subprocess.run(gov_init, capture_output=True, text=True, check=False).returncode, 0)

                base_gov_tfvars = {
                    "governance_project_id": "gov-proj-1",
                    "core_storage_project_id": "core-proj-1",
                    "primary_gold_project_id": "gold-proj-1",
                    "etl_compute_project_id": "etl-proj-1",
                    "bronze_dataset_id": "bronze",
                    "silver_dataset_id": "silver",
                    "assertions_dataset_id": "assertions",
                    "primary_gold_dataset_id": "gold",
                    "pii_masked_policy_tag_id": "projects/gov-proj-1/locations/asia-southeast1/taxonomies/1/policyTags/1",
                    "pii_restricted_policy_tag_id": "projects/gov-proj-1/locations/asia-southeast1/taxonomies/1/policyTags/2",
                }
                gov_tfvars_path = gov_dir / "val_test.auto.tfvars.json"

                gov_tfvars_path.write_text(
                    json.dumps({
                        **base_gov_tfvars,
                        "additional_dataform_repos": {
                            "retail": {
                                "git_url": "https://github.com/org/retail.git",
                                "git_token_secret_version": "projects/gov-proj-1/secrets/tok/versions/1",
                                "gold_project": "retail-gold-proj",
                                "gold_dataset": "retail_gold",
                            }
                        },
                    }),
                    encoding="utf-8",
                )
                ok_gov = subprocess.run(
                    [tf_bin, f"-chdir={gov_dir}", "console"],
                    input="var.additional_dataform_repos[\"retail\"].gold_project\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(ok_gov.returncode, 0, ok_gov.stderr)
                self.assertEqual(ok_gov.stdout.strip().strip('"'), "retail-gold-proj")

                gov_tfvars_path.write_text(
                    json.dumps({
                        **base_gov_tfvars,
                        "additional_dataform_repos": {
                            "retail": {"git_url": "https://github.com/org/retail.git"}
                        },
                    }),
                    encoding="utf-8",
                )
                missing_tok = subprocess.run(
                    [tf_bin, f"-chdir={gov_dir}", "console"],
                    input="keys(var.additional_dataform_repos)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", missing_tok.stderr)
                self.assertIn("git_token_secret_version", missing_tok.stderr)

                gov_tfvars_path.write_text(
                    json.dumps({
                        **base_gov_tfvars,
                        "additional_dataform_repos": {
                            "retail": {
                                "git_url": "https://github.com/org/retail.git",
                                "git_token_secret_version": "not-a-secret-version",
                            }
                        },
                    }),
                    encoding="utf-8",
                )
                bad_tok = subprocess.run(
                    [tf_bin, f"-chdir={gov_dir}", "console"],
                    input="keys(var.additional_dataform_repos)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", bad_tok.stderr)
                self.assertIn("projects/<project>/secrets/<secret>/versions/<version>", bad_tok.stderr)

                plat_dir = tmp_repo / "data" / "enterprise" / "01-platform"
                plat_versions = plat_dir / "versions.tf"
                plat_versions.write_text(
                    plat_versions.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                    encoding="utf-8",
                )
                shutil.rmtree(plat_dir / ".terraform", ignore_errors=True)
                plat_cached = REPO_ROOT / "data" / "enterprise" / "01-platform" / ".terraform" / "providers"
                plat_init = [tf_bin, f"-chdir={plat_dir}", "init", "-input=false"]
                if plat_cached.is_dir():
                    plat_init.append(f"-plugin-dir={plat_cached}")
                self.assertEqual(subprocess.run(plat_init, capture_output=True, text=True, check=False).returncode, 0)

                (plat_dir / "billing_val.auto.tfvars.json").write_text(
                    json.dumps({
                        "data_folder_id": "folders/123456",
                        "billing_account": "000000-000000-000000",
                        "domain_billing_accounts": {"fin": "   "},
                    }),
                    encoding="utf-8",
                )
                bad_billing = subprocess.run(
                    [tf_bin, f"-chdir={plat_dir}", "console"],
                    input="keys(var.domain_billing_accounts)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", bad_billing.stderr)
                self.assertIn("domain_billing_accounts", bad_billing.stderr)

    def test_remediation_hardening_and_link_aliases(self) -> None:
        net_main = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        self.assertIn("local.create_ngfw_ent && length(var.allowed_egress_fqdns) > 0", net_main)
        self.assertIn("local.create_vpc_fw_policy && !local.create_ngfw_ent && length(var.allowed_egress_fqdns) > 0", net_main)
        self.assertIn("allow_intra_vpc_egress", net_main)
        self.assertIn('resource "google_compute_router" "nat"', net_main)
        self.assertIn('resource "google_compute_router_nat" "this"', net_main)
        self.assertIn('action          = var.enable_secure_tags ? "goto_next" : "allow"', net_main)
        self.assertIn('service_name = "cloudkms.googleapis.com"', net_main)

        scc_main = (REPO_ROOT / "modules/foundation/scc-secops/main.tf").read_text(encoding="utf-8")
        self.assertIn('role    = "roles/pubsub.publisher"', scc_main)

        mon_main = (REPO_ROOT / "modules/foundation/monitoring-alerts/main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_monitoring_monitored_project" "workload"', mon_main)

        bdr_main = (REPO_ROOT / "modules/foundation/backup-dr/main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_project_service_identity" "backupdr"', bdr_main)
        self.assertIn('resource "google_kms_crypto_key_iam_member" "backupdr_cmek"', bdr_main)

        sb_main = (REPO_ROOT / "data/sandbox/main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_kms_crypto_key_iam_member" "storage_cmek"', sb_main)
        self.assertIn('resource "google_bigquery_datapolicy_data_policy_iam_member" "caller_masked_reader"', sb_main)

        ds_main = (REPO_ROOT / "data/enterprise/03-data-science/main.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_bigquery_dataset_iam_member" "aiplatform_ml_ops_audit_editor"', ds_main)

        deploy_wf = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("plan:", deploy_wf)
        self.assertIn('envs/shared.tfvars', deploy_wf)

        scc_script = (REPO_ROOT / "scripts/verify-scc-detectors.sh").read_text(encoding="utf-8")
        self.assertIn("gcloud alpha scc settings services describe", scc_script)
        self.assertIn("--quiet", scc_script)

        # Verify downstream 03-data-science / external output aliases in link-stages.sh.
        script_path = REPO_ROOT / "scripts/link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            src = tmp_path / "upstream"
            dst = tmp_path / "ds_downstream"
            for d in (bin_dir, src, dst):
                d.mkdir()
            (dst / "variables.tf").write_text(
                'variable "core_project_id" { type = string }\n'
                'variable "egress_connector_subnet_id" { type = string }\n'
                'variable "alert_notification_channel_ids" { type = list(string) }\n'
                'variable "kms_key_id" { type = string }\n'
                'variable "vpc_id" { type = string }\n'
                'variable "environment" { type = string }\n',
                encoding="utf-8",
            )
            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({\n"
                "  'core_storage_project_id': {'value': 'core-1', 'sensitive': False},\n"
                "  'ai_subnet_id': {'value': 'projects/n/regions/r/subnetworks/ai-snet', 'sensitive': False},\n"
                "  'subnet_id': {'value': 'projects/n/regions/r/subnetworks/base-snet', 'sensitive': False},\n"
                "  'notification_channel_ids': {'value': ['ch-1'], 'sensitive': False},\n"
                "  'kms_key_name': {'value': 'projects/p/locations/r/keyRings/k/cryptoKeys/c', 'sensitive': False},\n"
                "  'network_id': {'value': 'projects/n/global/networks/vpc-1', 'sensitive': False},\n"
                "}))\n",
                encoding="utf-8",
            )
            tf_shim.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            res = subprocess.run(
                [str(script_path), "--env", "uat", str(src), str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
            self.assertEqual(linked["core_project_id"], "core-1")
            self.assertEqual(linked["egress_connector_subnet_id"], "projects/n/regions/r/subnetworks/ai-snet")
            self.assertEqual(linked["alert_notification_channel_ids"], ["ch-1"])
            self.assertEqual(linked["kms_key_id"], "projects/p/locations/r/keyRings/k/cryptoKeys/c")
            self.assertEqual(linked["vpc_id"], "projects/n/global/networks/vpc-1")

    def test_fldr_prefix_prj_naming_and_merged_data_core_etl_defaults(self) -> None:
        org_main = (REPO_ROOT / "foundation/01-org-governance/main.tf").read_text(encoding="utf-8")
        for pid_expr in (
            'project_env_prefix         = "prj-${local.env_short}"',
            'audit_project_id           = "prj-coe-audit${local.project_suffix_tail}"',
            'finops_project_id          = "prj-coe-finops${local.project_suffix_tail}"',
            'backup_project_id          = "prj-coe-backup${local.project_suffix_tail}"',
            'secops_project_id          = "prj-coe-secops${local.project_suffix_tail}"',
        ):
            self.assertIn(pid_expr, org_main)

        plat_main = (REPO_ROOT / "data/enterprise/01-platform/main.tf").read_text(encoding="utf-8")
        plat_outs = (REPO_ROOT / "data/enterprise/01-platform/outputs.tf").read_text(encoding="utf-8")
        for expr in (
            'project_env_prefix          = "prj-${local.env_short}"',
            'data_gov_project_id  = "${local.project_env_prefix}-data-gov${local.project_suffix_tail}"',
            'data_core_project_id = "${local.project_env_prefix}-data-core${local.project_suffix_tail}"',
            'data_etl_project_id  = var.split_etl_project ? "${local.project_env_prefix}-data-etl${local.project_suffix_tail}" : local.data_core_project_id',
            'data_bi_project_id   = "${local.project_env_prefix}-data-bi${local.project_suffix_tail}"',
            'count  = var.split_etl_project ? 1 : 0',
            'count = local.use_cmek && var.split_etl_project ? 1 : 0',
            'count = local.use_cmek && var.manage_kms_iam && var.split_etl_project ? 1 : 0',
            'var.split_etl_project ? { etl = module.data_etl[0].project_number } : {}',
            'var.split_etl_project ? { etl = module.data_etl[0].project_id } : {}',
        ):
            self.assertIn(expr, plat_main)
        self.assertIn("value       = local.effective_etl_project_id", plat_outs)
        self.assertIn("local.effective_etl_project_number", plat_outs)

        import shutil
        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
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
                cached = REPO_ROOT / "data" / "enterprise" / "01-platform" / ".terraform" / "providers"
                init_cmd = [tf_bin, f"-chdir={plat_dir}", "init", "-input=false"]
                if cached.is_dir():
                    init_cmd.append(f"-plugin-dir={cached}")
                self.assertEqual(subprocess.run(init_cmd, capture_output=True, text=True, check=False).returncode, 0)

                # Default: create_data_subfolders = false, split_etl_project = false.
                (plat_dir / "merged_test.auto.tfvars.json").write_text(
                    json.dumps({
                        "environment": "prod",
                        "prefix": "acme",
                        "billing_account": "000000-000000-000000",
                        "environment_data_folder_ids": {"prod": "folders/777888"},
                    }),
                    encoding="utf-8",
                )
                res_merged = subprocess.run(
                    [tf_bin, f"-chdir={plat_dir}", "console"],
                    input='jsonencode({ create_sub = local.create_subfolders, storage_f = local.effective_storage_folder_id, compute_f = local.effective_compute_folder_id, gov = local.data_gov_project_id, core = local.data_core_project_id, etl = local.data_etl_project_id, bi = local.data_bi_project_id })\n',
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res_merged.returncode, 0, res_merged.stderr)
                parsed = json.loads(json.loads(res_merged.stdout.strip()))
                self.assertFalse(parsed["create_sub"])
                self.assertEqual(parsed["storage_f"], "folders/777888")
                self.assertEqual(parsed["compute_f"], "folders/777888")
                self.assertRegex(parsed["gov"], r"^prj-prod-data-gov-[0-9a-f]{4}$")
                self.assertRegex(parsed["core"], r"^prj-prod-data-core-[0-9a-f]{4}$")
                self.assertEqual(parsed["etl"], parsed["core"])
                self.assertRegex(parsed["bi"], r"^prj-prod-data-bi-[0-9a-f]{4}$")

                # Opt-in: create_data_subfolders = true, split_etl_project = true.
                (plat_dir / "merged_test.auto.tfvars.json").write_text(
                    json.dumps({
                        "environment": "uat",
                        "prefix": "acme",
                        "billing_account": "000000-000000-000000",
                        "data_folder_id": "777888",
                        "create_data_subfolders": True,
                        "split_etl_project": True,
                    }),
                    encoding="utf-8",
                )
                res_split = subprocess.run(
                    [tf_bin, f"-chdir={plat_dir}", "console"],
                    input='jsonencode({ create_sub = local.create_subfolders, create_st = local.create_storage_subfolder, create_cp = local.create_compute_subfolder, parent_f = local.parent_folder, core = local.data_core_project_id, etl = local.data_etl_project_id })\n',
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res_split.returncode, 0, res_split.stderr)
                parsed_split = json.loads(json.loads(res_split.stdout.strip()))
                self.assertTrue(parsed_split["create_sub"])
                self.assertTrue(parsed_split["create_st"])
                self.assertTrue(parsed_split["create_cp"])
                self.assertEqual(parsed_split["parent_f"], "folders/777888")
                self.assertRegex(parsed_split["core"], r"^prj-uat-data-core-[0-9a-f]{4}$")
                self.assertRegex(parsed_split["etl"], r"^prj-uat-data-etl-[0-9a-f]{4}$")

    def test_greenfield_offline_terraform_plan_across_all_stages(self) -> None:
        import shutil
        tf_bin = shutil.which("terraform")
        if tf_bin is None:
            self.skipTest("terraform binary not installed")

        plan_cases = (
            ("foundation/00-bootstrap", "bootstrap", {"project_id": "seed-admin-project-01"}),
            ("foundation/01-org-governance", "org_none", {"parent_id": "organizations/123456789012", "billing_account": "000000-000000-000000", "scc_tier": "NONE"}),
            ("foundation/01-org-governance", "org_standard", {"parent_id": "organizations/123456789012", "billing_account": "000000-000000-000000", "scc_tier": "STANDARD", "scc_alert_email_addresses": ["secops@example.com"]}),
            ("foundation/01-org-governance", "org_premium", {"parent_id": "organizations/123456789012", "billing_account": "000000-000000-000000", "scc_tier": "PREMIUM", "scc_alert_email_addresses": ["secops@example.com"], "enable_security_posture": True}),
            (
                "foundation/02-security-network",
                "net_sec",
                {
                    "billing_account": "000000-000000-000000",
                    "network_folder_id": "folders/123456",
                    "enable_vpc": True,
                    "enable_shared_vpc_host": True,
                    "enable_psc": True,
                    "enable_vpc_sc": True,
                    "access_policy_id": "123456",
                    "department_subnet_cidrs": {"data": "10.20.32.0/22", "ai": "10.20.36.0/22", "app": "10.20.40.0/22"},
                },
            ),
            ("data/enterprise/01-platform", "plat_merged_no_vpcsc", {"billing_account": "000000-000000-000000", "data_folder_id": "folders/123456", "split_etl_project": False, "vpc_sc_perimeter_name": ""}),
            ("data/enterprise/01-platform", "plat_merged_vpcsc", {"billing_account": "000000-000000-000000", "data_folder_id": "folders/123456", "split_etl_project": False, "vpc_sc_perimeter_name": "accessPolicies/1/servicePerimeters/p", "kms_key_id": "projects/p/locations/asia-southeast1/keyRings/k/cryptoKeys/c", "shared_vpc_host_project_id": "prj-dev-network-1234", "subnet_id": "projects/prj-dev-network-1234/regions/asia-southeast1/subnetworks/snet"}),
            ("data/enterprise/01-platform", "plat_split_no_vpcsc", {"billing_account": "000000-000000-000000", "data_folder_id": "folders/123456", "split_etl_project": True, "vpc_sc_perimeter_name": ""}),
            ("data/enterprise/01-platform", "plat_split_vpcsc", {"billing_account": "000000-000000-000000", "data_folder_id": "folders/123456", "split_etl_project": True, "vpc_sc_perimeter_name": "accessPolicies/1/servicePerimeters/p", "kms_key_id": "projects/p/locations/asia-southeast1/keyRings/k/cryptoKeys/c", "shared_vpc_host_project_id": "prj-dev-network-1234", "subnet_id": "projects/prj-dev-network-1234/regions/asia-southeast1/subnetworks/snet"}),
            ("data/enterprise/03-data-science", "ds_tier_s", {"billing_account": "000000-000000-000000", "ai_folder_id": "folders/123456", "etl_compute_project_id": "prj-dev-data-core-1234", "team_size_tier": "S", "vpc_sc_perimeter_name": "accessPolicies/1/servicePerimeters/p", "kms_key_id": "projects/p/locations/asia-southeast1/keyRings/k/cryptoKeys/c", "shared_vpc_host_project_id": "prj-dev-network-1234", "vpc_id": "projects/prj-dev-network-1234/global/networks/vpc", "subnet_id": "projects/prj-dev-network-1234/regions/asia-southeast1/subnetworks/ai-snet"}),
            ("data/enterprise/03-data-science", "ds_tier_m", {"billing_account": "000000-000000-000000", "ai_folder_id": "folders/123456", "team_size_tier": "M", "vpc_sc_perimeter_name": "accessPolicies/1/servicePerimeters/p", "kms_key_id": "projects/p/locations/asia-southeast1/keyRings/k/cryptoKeys/c", "shared_vpc_host_project_id": "prj-dev-network-1234", "vpc_id": "projects/prj-dev-network-1234/global/networks/vpc", "subnet_id": "projects/prj-dev-network-1234/regions/asia-southeast1/subnetworks/ai-snet"}),
            ("apps/enterprise", "apps", {"billing_account": "000000-000000-000000", "app_folder_id": "folders/123456", "vpc_sc_perimeter_name": "accessPolicies/1/servicePerimeters/p", "kms_key_id": "projects/p/locations/asia-southeast1/keyRings/k/cryptoKeys/c", "shared_vpc_host_project_id": "prj-dev-network-1234", "subnet_id": "projects/prj-dev-network-1234/regions/asia-southeast1/subnetworks/app-snet", "applications": {"web": {"display_name": "Web"}}}),
        )

        env = os.environ.copy()
        env["GOOGLE_OAUTH_ACCESS_TOKEN"] = "offline-plan-dummy-token"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_repo = Path(tmp) / "repo"
            for top in ("modules", "foundation", "data", "apps"):
                shutil.copytree(
                    REPO_ROOT / top,
                    tmp_repo / top,
                    ignore=shutil.ignore_patterns(".terraform", "__pycache__", "*.auto.tfvars*"),
                )

            initialized: set[str] = set()
            for stage_rel, case_name, tfvars in plan_cases:
                stage_dir = tmp_repo / stage_rel
                if stage_rel not in initialized:
                    versions_path = stage_dir / "versions.tf"
                    if versions_path.is_file():
                        versions_path.write_text(
                            versions_path.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                            encoding="utf-8",
                        )
                    init_cmd = [tf_bin, f"-chdir={stage_dir}", "init", "-input=false"]
                    cached = REPO_ROOT / stage_rel / ".terraform" / "providers"
                    if cached.is_dir():
                        init_cmd.append(f"-plugin-dir={cached}")
                    init_res = subprocess.run(init_cmd, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
                    self.assertEqual(init_res.returncode, 0, f"init {stage_rel}: {init_res.stderr}")
                    initialized.add(stage_rel)

                (stage_dir / "greenfield_test.auto.tfvars.json").write_text(json.dumps(tfvars), encoding="utf-8")
                with self.subTest(case=case_name):
                    plan_res = subprocess.run(
                        [tf_bin, f"-chdir={stage_dir}", "plan", "-refresh=false", "-input=false"],
                        env=env,
                        stdin=subprocess.DEVNULL,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(plan_res.returncode, 0, f"{case_name} plan failed:\n{plan_res.stderr}")

    def test_remediation_item_invariants(self) -> None:
        wf_text = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3", wf_text)
        self.assertNotIn("google-github-actions/auth@c200f369", wf_text)
        self.assertIn("vars.GCP_PR_PLAN_STAGE", wf_text)
        self.assertIn("Guard against shared stage in environment deploy", wf_text)

        gov_ex = (REPO_ROOT / "data/enterprise/02-governance-ops/terraform.tfvars.example").read_text(encoding="utf-8")
        for key in ("bronze_dataset_id", "assertions_dataset_id", "pii_masked_policy_tag_id", "pii_restricted_policy_tag_id"):
            self.assertRegex(gov_ex, rf"(?m)^#\s*{key}\s*=")

        net_sec = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        self.assertIn("ai   = 0", net_sec)
        self.assertIn("app  = 1", net_sec)
        self.assertIn("data = 2", net_sec)

        sec_vars = (REPO_ROOT / "foundation/02-security-network/variables.tf").read_text(encoding="utf-8")
        self.assertRegex(sec_vars, r'variable\s+"enable_vertex_psc_policy"[\s\S]*?default\s*=\s*true')

        finops_main = (REPO_ROOT / "modules/foundation/finops-governance/main.tf").read_text(encoding="utf-8")
        self.assertIn('startswith(trimspace(num), "projects/")', finops_main)

        for script_rel in ("scripts/configure-bq-dr-replica.sh", "scripts/verify-scc-detectors.sh"):
            self.assertIn("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", (REPO_ROOT / script_rel).read_text(encoding="utf-8"))

        for script_rel, bad_proj in (
            ("scripts/configure-bq-dr-replica.sh", "demo-proj-"),
            ("scripts/verify-scc-detectors.sh", "demo-proj-"),
        ):
            res = subprocess.run(
                [str(REPO_ROOT / script_rel), "--project", bad_proj],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 2)


if __name__ == "__main__":
    unittest.main()
