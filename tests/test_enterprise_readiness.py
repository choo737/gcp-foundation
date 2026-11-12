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
            exported = json.loads((gcs_store / "b" / "merged.json").read_text(encoding="utf-8"))
            self.assertEqual(exported, {"environment": "staging", "kms_key_id": "k1", "vpc_id": "v2"})

            res2 = subprocess.run(
                [str(script_path), "--env", "prod", "--from-gcs", "gs://b/merged.json", str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res2.returncode, 0, res2.stderr)
            linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
            self.assertEqual(linked, {"environment": "prod", "kms_key_id": "k1", "vpc_id": "v2"})

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


if __name__ == "__main__":
    unittest.main()
