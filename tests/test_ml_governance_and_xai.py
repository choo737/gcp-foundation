"""Verify Data Science, MLOps, Separation-of-Duties IAM, and Regulated XAI controls."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent

XAI_LEDGER_COLUMNS = [
    ("decision_id", "STRING", "REQUIRED"),
    ("entity_id", "STRING", "REQUIRED"),
    ("decision_timestamp", "TIMESTAMP", "REQUIRED"),
    ("serving_track", "STRING", "REQUIRED"),
    ("model_id", "STRING", "REQUIRED"),
    ("model_version_id", "STRING", "REQUIRED"),
    ("model_artifact_sha256", "STRING", "REQUIRED"),
    ("container_image_digest", "STRING", "REQUIRED"),
    ("schema_version", "STRING", "REQUIRED"),
    ("explained_class", "STRING", "REQUIRED"),
    ("approve_prob", "FLOAT", "REQUIRED"),
    ("raw_margin", "FLOAT", "REQUIRED"),
    ("base_logit", "FLOAT", "REQUIRED"),
    ("shap_sum_logit", "FLOAT", "REQUIRED"),
    ("shap_logit_map", "JSON", "REQUIRED"),
    ("top_adverse_reasons", "JSON", "REQUIRED"),
    ("feature_payload", "JSON", "REQUIRED"),
    ("reason_rule_version", "STRING", "REQUIRED"),
]


class MlGovernanceAndXaiTest(unittest.TestCase):
    """Validate 03-data-science stage, ml-governance module, VPC-SC, Org Policies, and XAI ledger."""

    def test_bootstrap_tf_ds_ci_and_prefix_isolation(self) -> None:
        boot_vars = (REPO_ROOT / "foundation/00-bootstrap/variables.tf").read_text(encoding="utf-8")
        boot_main = (REPO_ROOT / "foundation/00-bootstrap/main.tf").read_text(encoding="utf-8")
        boot_outs = (REPO_ROOT / "foundation/00-bootstrap/outputs.tf").read_text(encoding="utf-8")

        self.assertIn('"tf_ds_ci"', boot_vars)
        self.assertIn("-tf-ds-ci", boot_main)
        self.assertIn('tf_ds_ci        = "data-science/"', boot_main)
        self.assertIn('api.getAttribute(\\"storage.googleapis.com/objectListPrefix\\", \\"\\").startsWith(\\"data-science/\\")', boot_main)
        self.assertIn('api.getAttribute(\\"storage.googleapis.com/objectListPrefix\\", \\"\\") == \\"data-science\\"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_ds_viewer"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_ds_prefix_admin"', boot_main)
        self.assertIn('output "tf_ds_ci_sa_email"', boot_outs)

    def test_org_policies_audit_logs_and_vpc_sc_services_and_dns(self) -> None:
        lg_vars = (REPO_ROOT / "modules/foundation/logging-guardrails/variables.tf").read_text(encoding="utf-8")
        for constraint in ("ainotebooks.disableRootAccess", "ainotebooks.disableFileDownloads"):
            self.assertIn(f'"{constraint}"', lg_vars)
        for audit_svc in ("aiplatform.googleapis.com", "notebooks.googleapis.com"):
            self.assertIn(f'"{audit_svc}"', lg_vars)

        net_main = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        match = re.search(r"vpc_sc_restricted_services\s*=\s*\[([\s\S]*?)\]", net_main)
        self.assertIsNotNone(match)
        restricted = re.findall(r'"([^"]+)"', match.group(1))
        self.assertEqual(len(restricted), 21)
        for svc in ("aiplatform.googleapis.com", "notebooks.googleapis.com", "datalineage.googleapis.com"):
            self.assertIn(svc, restricted)
        for forbidden in ("bigquerystorage.googleapis.com", "bigqueryreservation.googleapis.com", "workflowexecutions.googleapis.com"):
            self.assertNotIn(forbidden, restricted)

        for dns_zone in ("notebooks.googleapis.com.", "notebooks.cloud.google.com.", "kernels.googleusercontent.com."):
            self.assertIn(f'"{dns_zone}"', net_main)

    def test_ml_governance_module_hardening_and_xai_ledger_schema(self) -> None:
        mod_dir = REPO_ROOT / "modules/data/ml-governance"
        ml_main = (mod_dir / "main.tf").read_text(encoding="utf-8")
        ml_vars = (mod_dir / "variables.tf").read_text(encoding="utf-8")

        self.assertNotIn("google_notebooks_instance", ml_main)
        self.assertNotIn("explanation_spec", ml_main)
        self.assertIn('resource "google_workbench_instance" "this"', ml_main)
        self.assertIn('resource "google_workbench_instance_iam_member" "owner_admin"', ml_main)
        self.assertIn('role     = "roles/notebooks.admin"', ml_main)
        self.assertIn("disable_public_ip    = true", ml_main)
        self.assertIn("enable_secure_boot          = true", ml_main)
        for md_flag in (
            'notebook-disable-root      = "true"',
            'notebook-disable-downloads = "true"',
            'notebook-disable-nbconvert = "true"',
            'notebook-disable-terminal  = "true"',
            'idle-timeout-seconds       = tostring(var.workbench_idle_timeout_seconds)',
        ):
            self.assertIn(md_flag, ml_main)
        self.assertRegex(ml_vars, r'variable\s+"workbench_idle_timeout_seconds"[\s\S]*?default\s*=\s*3600')

        self.assertIn('resource "google_colab_runtime_template" "this"', ml_main)
        self.assertIn('var.enable_colab_enterprise && var.compliance_profile == "regulated_fsi_rmit"', ml_main)
        self.assertIn('resource "google_artifact_registry_repository" "ml_cpr"', ml_main)
        self.assertIn('repository_id = "${var.prefix}-ml-cpr"', ml_main)
        self.assertIn('resource "google_vertex_ai_metadata_store" "default"', ml_main)
        self.assertIn('provider = google-beta', ml_main)
        self.assertIn('resource "google_storage_bucket" "xai_worm"', ml_main)
        self.assertIn('retention_period = var.xai_audit_retention_days * 86400', ml_main)
        self.assertIn('is_locked        = var.environment == "prod"', ml_main)

        self.assertIn('table_id                 = "ml_xai_audit_ledger"', ml_main)
        self.assertIn("require_partition_filter = true", ml_main)
        self.assertIn('field = "decision_timestamp"', ml_main)
        self.assertIn('clustering               = ["serving_track", "model_id", "explained_class", "entity_id"]', ml_main)
        self.assertIn('deletion_protection      = var.environment != "dev"', ml_main)

        schema_match = re.search(r"schema\s*=\s*jsonencode\((\[[\s\S]*?\])\)", ml_main)
        self.assertIsNotNone(schema_match)
        parsed_cols = re.findall(
            r'name\s*=\s*"([^"]+)"\s+type\s*=\s*"([^"]+)"\s+mode\s*=\s*"([^"]+)"',
            schema_match.group(1),
        )
        self.assertEqual(parsed_cols, XAI_LEDGER_COLUMNS)

        self.assertIn('resource "google_bigquery_table" "ml_training_labels"', ml_main)
        self.assertIn('table_id                 = "ml_training_labels"', ml_main)
        self.assertIn('field = "label_timestamp"', ml_main)
        self.assertIn('clustering               = ["entity_id", "approved_flag"]', ml_main)
        labels_block = ml_main.split('resource "google_bigquery_table" "ml_training_labels"', 1)[1]
        labels_schema_match = re.search(r"schema\s*=\s*jsonencode\((\[[\s\S]*?\])\)", labels_block)
        self.assertIsNotNone(labels_schema_match)
        labels_cols = re.findall(
            r'name\s*=\s*"([^"]+)"\s+type\s*=\s*"([^"]+)"\s+mode\s*=\s*"([^"]+)"',
            labels_schema_match.group(1),
        )
        self.assertEqual(
            labels_cols,
            [
                ("application_id", "STRING", "REQUIRED"),
                ("entity_id", "STRING", "REQUIRED"),
                ("label_timestamp", "TIMESTAMP", "REQUIRED"),
                ("approved_flag", "INT64", "REQUIRED"),
                ("demographic_group", "STRING", "NULLABLE"),
            ],
        )

        for api_svc in ("pubsub.googleapis.com", "workflows.googleapis.com", "run.googleapis.com"):
            self.assertIn(f'"{api_svc}"', ml_main)
        self.assertIn('resource "google_project_service_identity" "ml_ops_runtime"', ml_main)
        self.assertIn('resource "google_kms_crypto_key_iam_member" "ml_ops_runtime_cmek"', ml_main)
        self.assertIn('resource "google_network_connectivity_service_connection_policy" "vertex_psc"', ml_main)
        self.assertIn('service_class = "gcp-vertexai"', ml_main)
        self.assertIn('service                    = "networkconnectivity.googleapis.com"', ml_main)
        self.assertIn('variable "enable_vertex_psc_policy"', ml_vars)
        ml_outs = (mod_dir / "outputs.tf").read_text(encoding="utf-8")
        self.assertIn('output "ml_training_labels_table_id"', ml_outs)
        self.assertIn('output "vertex_psc_service_connection_policy_id"', ml_outs)

        self.assertIn('resource "google_dataplex_datascan" "xai_audit"', ml_main)
        self.assertIn("row_condition_expectation", ml_main)
        self.assertIn("ABS((base_logit + shap_sum_logit) - raw_margin) <= ${local.shap_tolerance_string} * GREATEST(1.0, ABS(raw_margin))", ml_main)
        self.assertIn("non_null_expectation", ml_main)
        self.assertIn('column      = "container_image_digest"', ml_main)
        self.assertIn('column      = "model_artifact_sha256"', ml_main)

    def test_stage_03_tier_split_sod_iam_and_outputs(self) -> None:
        ds_dir = REPO_ROOT / "data/enterprise/03-data-science"
        ds_main = (ds_dir / "main.tf").read_text(encoding="utf-8")
        ds_vars = (ds_dir / "variables.tf").read_text(encoding="utf-8")
        ds_outs = (ds_dir / "outputs.tf").read_text(encoding="utf-8")

        self.assertRegex(ds_vars, r'variable\s+"enable_data_science"[\s\S]*?default\s*=\s*true')
        self.assertRegex(ds_vars, r'variable\s+"team_size_tier"[\s\S]*?default\s*=\s*"M"')
        self.assertIn('local.is_small_tier ? local.trimmed_etl_proj : module.ds_exp_project[0].project_id', ds_main)
        self.assertIn('local.is_small_tier ? local.trimmed_etl_proj : module.ml_ops_project[0].project_id', ds_main)
        self.assertIn('ds_exp_project_id_candidate = "${local.project_prefix}-ds-exp"', ds_main)
        self.assertIn('ml_ops_project_id_candidate = "${local.project_prefix}-ml-ops"', ds_main)

        # SoD IAM invariants (strip comments before asserting).
        ds_main_code = "\n".join(
            line for line in ds_main.splitlines() if not line.lstrip().startswith("#")
        )
        self.assertNotIn("roles/notebooks.runner", ds_main_code)
        self.assertNotIn("pii_restricted", ds_main_code)
        self.assertNotIn("categoryFineGrainedReader", ds_main_code)
        self.assertIn('role    = "roles/aiplatform.viewer"', ds_main)
        self.assertIn('role           = "roles/bigquerydatapolicy.maskedReader"', ds_main)
        self.assertIn('var.team_size_tier != "S" || var.environment != "prod"', ds_main)
        self.assertNotIn('project = local.effective_ml_ops_project_id\n  role    = "roles/aiplatform.user"', ds_main)

        for out_name in (
            "ds_exp_project_id",
            "ml_ops_project_id",
            "ml_artifact_repo_id",
            "ml_audit_dataset_id",
            "ml_audit_table_id",
            "ml_training_labels_table_id",
            "vertex_psc_service_connection_policy_id",
            "ml_worm_bucket_name",
            "shap_additivity_tolerance",
            "core_storage_project_id",
            "silver_dataset_id",
            "kms_key_id",
            "vpc_id",
            "subnet_id",
            "notification_channel_ids",
            "region",
            "prefix",
            "environment",
        ):
            self.assertIn(f'output "{out_name}"', ds_outs)

        gov_main = (REPO_ROOT / "data/enterprise/02-governance-ops/main.tf").read_text(encoding="utf-8")
        gov_vars = (REPO_ROOT / "data/enterprise/02-governance-ops/variables.tf").read_text(encoding="utf-8")
        self.assertIn('variable "ml_ops_project_id"', gov_vars)
        self.assertIn('variable "ml_audit_dataset_id"', gov_vars)
        self.assertIn("ml_audit_project   = local.effective_ml_audit_project", gov_main)
        self.assertIn("ml_audit_dataset   = local.effective_ml_audit_dataset", gov_main)
        self.assertIn('resource "google_bigquery_dataset_iam_member" "dataform_etl_ml_audit_viewer"', gov_main)
        self.assertIn('data "google_project" "ml_ops"', gov_main)
        self.assertIn('resource "terraform_data" "validate_ml_audit_inputs"', gov_main)
        self.assertIn('"run.googleapis.com"', ds_main)
        self.assertIn('resource "google_compute_shared_vpc_service_project" "ml_ops"', ds_main)
        self.assertIn('resource "google_project_service_identity" "cloudrun_ml_ops"', ds_main)
        self.assertIn('resource "google_compute_subnetwork_iam_member" "cloudrun_ml_ops_network_user"', ds_main)
        self.assertIn('resource "google_bigquery_dataset_iam_member" "aiplatform_ml_ops_silver_viewer"', ds_main)
        self.assertIn('resource "google_project_iam_member" "aiplatform_ml_ops_bq_job_user"', ds_main)

    def test_stage_03_tier_resolution_and_colab_fsi_block_with_terraform(self) -> None:
        tf_bin = shutil.which("terraform")
        if tf_bin is None:
            self.skipTest("terraform binary not installed")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_repo = Path(tmp) / "repo"
            shutil.copytree(REPO_ROOT / "modules", tmp_repo / "modules")
            shutil.copytree(REPO_ROOT / "data", tmp_repo / "data")
            ds_dir = tmp_repo / "data" / "enterprise" / "03-data-science"
            versions_path = ds_dir / "versions.tf"
            versions_path.write_text(
                versions_path.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                encoding="utf-8",
            )
            shutil.rmtree(ds_dir / ".terraform", ignore_errors=True)
            cached = REPO_ROOT / "data" / "enterprise" / "03-data-science" / ".terraform" / "providers"
            init_cmd = [tf_bin, f"-chdir={ds_dir}", "init", "-input=false"]
            if cached.is_dir():
                init_cmd.append(f"-plugin-dir={cached}")
            init_res = subprocess.run(init_cmd, capture_output=True, text=True, check=False)
            self.assertEqual(init_res.returncode, 0, init_res.stderr)

            tfvars_path = ds_dir / "test_eval.auto.tfvars.json"
            tfvars_path.write_text(
                json.dumps({
                    "enable_data_science": False,
                    "prefix": "abcdefgh",
                    "project_suffix": "12345678",
                }),
                encoding="utf-8",
            )
            res_disabled = subprocess.run(
                [tf_bin, f"-chdir={ds_dir}", "console"],
                input="local.effective_ds_exp_project_id\n",
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res_disabled.returncode, 0, res_disabled.stderr)
            self.assertEqual(res_disabled.stdout.strip().strip('"'), "")

            res_len = subprocess.run(
                [tf_bin, f"-chdir={ds_dir}", "console"],
                input="length(local.ds_exp_project_id_candidate) <= 30 && length(local.ml_ops_project_id_candidate) <= 30\n",
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res_len.returncode, 0, res_len.stderr)
            self.assertEqual(res_len.stdout.strip(), "true")

            tfvars_path.write_text(
                json.dumps({
                    "enable_data_science": True,
                    "team_size_tier": "S",
                    "etl_compute_project_id": "ent-dev01-data-etl",
                    "compliance_profile": "regulated_fsi_rmit",
                    "enable_colab_enterprise": True,
                }),
                encoding="utf-8",
            )
            res_fsi_plan = subprocess.run(
                [tf_bin, f"-chdir={ds_dir}", "plan", "-refresh=false", "-input=false"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(res_fsi_plan.returncode, 0)
            self.assertIn("regulated_fsi_rmit", res_fsi_plan.stderr)


if __name__ == "__main__":
    unittest.main()
