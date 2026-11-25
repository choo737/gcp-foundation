"""Verify Option B tiered Security Command Center (NONE, STANDARD, PREMIUM) controls."""

import os
from pathlib import Path
import re
import stat
import subprocess
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCC_MOD_DIR = REPO_ROOT / "modules" / "foundation" / "scc-secops"
ORG_STAGE_DIR = REPO_ROOT / "foundation" / "01-org-governance"


class SccSecOpsTest(unittest.TestCase):
    """Validate scc-secops module schemas, tier gating, and Stage 01 wiring."""

    def test_scc_tier_and_location_validations(self) -> None:
        mod_vars = (SCC_MOD_DIR / "variables.tf").read_text(encoding="utf-8")
        org_vars = (ORG_STAGE_DIR / "variables.tf").read_text(encoding="utf-8")

        for label, text in (("scc-secops", mod_vars), ("01-org-governance", org_vars)):
            with self.subTest(target=label):
                self.assertRegex(
                    text,
                    r'variable\s+"scc_tier"[\s\S]*?default\s*=\s*"NONE"[\s\S]*?contains\(\["NONE",\s*"STANDARD",\s*"PREMIUM"\],\s*var\.scc_tier\)',
                )
                self.assertRegex(
                    text,
                    r'variable\s+"scc_location"[\s\S]*?default\s*=\s*"global"[\s\S]*?contains\(\["global",\s*"us",\s*"eu",\s*"sa"\],\s*var\.scc_location\)',
                )

    def test_standard_tier_export_iam_alerts_and_nonprod_mutes(self) -> None:
        mod_main = (SCC_MOD_DIR / "main.tf").read_text(encoding="utf-8")
        mod_vars = (SCC_MOD_DIR / "variables.tf").read_text(encoding="utf-8")

        self.assertIn('enable_standard = contains(["STANDARD", "PREMIUM"], var.scc_tier)', mod_main)
        self.assertRegex(mod_vars, r'variable\s+"region"[\s\S]*?default\s*=\s*"asia-southeast1"')
        self.assertRegex(mod_vars, r'variable\s+"nonprod_mute_environments"[\s\S]*?default\s*=\s*\["dev",\s*"uat"\]')

        self.assertIn('resource "google_bigquery_dataset" "scc_findings"', mod_main)
        self.assertIn("location                   = var.region", mod_main)
        self.assertIn("max_time_travel_hours      = 168", mod_main)

        self.assertIn('resource "google_scc_v2_folder_scc_big_query_export" "active_findings"', mod_main)
        self.assertIn('filter              = "state=\\"ACTIVE\\" AND NOT mute=\\"MUTED\\""', mod_main)

        self.assertIn('resource "google_bigquery_dataset_iam_member" "scc_export_writer"', mod_main)
        self.assertIn('role       = "roles/bigquery.dataEditor"', mod_main)
        self.assertIn("active_findings[0].principal", mod_main)

        self.assertIn('resource "google_pubsub_topic" "scc_findings"', mod_main)
        self.assertIn('resource "google_pubsub_subscription" "scc_findings_alert"', mod_main)
        self.assertIn('resource "google_scc_v2_folder_notification_config" "high_critical"', mod_main)
        self.assertIn('resource "google_monitoring_notification_channel" "scc_email"', mod_main)
        self.assertIn('resource "google_monitoring_alert_policy" "scc_unacked_findings"', mod_main)
        self.assertIn("pubsub.googleapis.com/topic/send_message_operation_count", mod_main)
        self.assertIn('auto_close = "1800s"', mod_main)

        self.assertIn('resource "google_scc_v2_folder_mute_config" "nonprod"', mod_main)
        mute_type_token = 'type           = "' + "DYN" + 'AMIC"'
        self.assertIn(mute_type_token, mod_main)
        self.assertIn("var.nonprod_mute_environments", mod_main)

    def test_premium_tier_custom_sha_and_security_posture(self) -> None:
        mod_main = (SCC_MOD_DIR / "main.tf").read_text(encoding="utf-8")

        self.assertIn('enable_premium  = var.scc_tier == "PREMIUM"', mod_main)
        self.assertIn(
            'resource "google_scc_management_folder_security_health_analytics_custom_module" "prod_bq_cmek"',
            mod_main,
        )
        self.assertIn('lookup(var.environment_folder_ids, "prod", "")', mod_main)
        self.assertIn('folder           = local.prod_folder_id', mod_main)
        self.assertIn('resource_types = ["bigquery.googleapis.com/Dataset"]', mod_main)
        self.assertIn("defaultEncryptionConfiguration", mod_main)

        self.assertIn(
            'resource "google_scc_management_folder_security_health_analytics_custom_module" "gcs_ubla"',
            mod_main,
        )
        self.assertIn('resource_types = ["storage.googleapis.com/Bucket"]', mod_main)
        self.assertIn("uniformBucketLevelAccess", mod_main)

        self.assertIn('resource "google_securityposture_posture" "foundation"', mod_main)
        self.assertIn('resource "google_securityposture_posture_deployment" "root_folder"', mod_main)
        self.assertIn('canned_constraint_id = "storage.uniformBucketLevelAccess"', mod_main)
        self.assertIn('canned_constraint_id = "iam.disableServiceAccountKeyCreation"', mod_main)
        self.assertIn('canned_constraint_id = "sql.restrictPublicIp"', mod_main)
        self.assertIn("google_securityposture_posture.foundation[0].revision_id", mod_main)

    def test_stage_01_wiring_and_legacy_backwards_compatibility(self) -> None:
        org_main = (ORG_STAGE_DIR / "main.tf").read_text(encoding="utf-8")
        org_outs = (ORG_STAGE_DIR / "outputs.tf").read_text(encoding="utf-8")
        lg_main = (REPO_ROOT / "modules" / "foundation" / "logging-guardrails" / "main.tf").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'effective_scc_tier     = var.scc_tier != "NONE" ? var.scc_tier : (var.enable_scc_notifications ? "STANDARD" : "NONE")',
            org_main,
        )
        self.assertRegex(
            org_main,
            r'module\s+"logging_guardrails"[\s\S]*?enable_scc_notifications\s*=\s*false',
        )
        self.assertIn('"securitycenter.googleapis.com"', org_main)
        self.assertIn('"monitoring.googleapis.com"', org_main)
        self.assertIn('"securitycentermanagement.googleapis.com"', org_main)
        self.assertIn('"securityposture.googleapis.com"', org_main)
        self.assertIn('module "scc_secops"', org_main)
        self.assertIn("environment_folder_ids     = module.folder_hierarchy.environment_folder_ids", org_main)
        self.assertIn("depends_on = [time_sleep.audit_api_propagation]", org_main)

        self.assertIn('resource "google_scc_v2_folder_notification_config" "high_critical"', lg_main)

        for out_name in (
            "scc_tier",
            "scc_scope",
            "scc_findings_dataset_id",
            "scc_big_query_export_name",
            "scc_findings_topic_id",
            "scc_pubsub_topic_id",
            "scc_findings_subscription_id",
            "scc_custom_sha_module_ids",
            "scc_custom_etd_module_id",
            "scc_posture_deployment_id",
            "audit_kms_key_id",
        ):
            with self.subTest(output=out_name):
                self.assertIn(f'output "{out_name}"', org_outs)

    def test_stage_01_cmek_project_scope_push_etd_and_verifier_script(self) -> None:
        org_main = (ORG_STAGE_DIR / "main.tf").read_text(encoding="utf-8")
        org_vars = (ORG_STAGE_DIR / "variables.tf").read_text(encoding="utf-8")
        mod_main = (SCC_MOD_DIR / "main.tf").read_text(encoding="utf-8")
        mod_vars = (SCC_MOD_DIR / "variables.tf").read_text(encoding="utf-8")

        self.assertRegex(org_vars, r'variable\s+"enable_audit_cmek"[\s\S]*?default\s*=\s*true')
        self.assertRegex(org_vars, r'variable\s+"audit_kms_protection_level"[\s\S]*?default\s*=\s*"SOFTWARE"')
        self.assertIn('"cloudkms.googleapis.com"', org_main)
        self.assertIn('resource "google_kms_key_ring" "audit"', org_main)
        self.assertIn('resource "google_kms_crypto_key" "audit_cmek"', org_main)
        self.assertIn("@bigquery-encryption.iam.gserviceaccount.com", org_main)
        self.assertIn("@gcp-sa-pubsub.iam.gserviceaccount.com", org_main)
        self.assertIn("siem_kms_key_id", org_main)

        self.assertRegex(mod_vars, r'variable\s+"scc_scope"[\s\S]*?default\s*=\s*"FOLDER"')
        self.assertRegex(mod_vars, r'contains\(\["ORGANIZATION",\s*"FOLDER",\s*"PROJECT"\],\s*var\.scc_scope\)')
        self.assertIn('resource "google_scc_v2_organization_scc_big_query_export" "org_active_findings"', mod_main)
        self.assertIn('resource "google_scc_v2_organization_notification_config" "org_high_critical"', mod_main)
        self.assertIn('resource "google_scc_management_organization_security_health_analytics_custom_module" "org_gcs_ubla"', mod_main)
        self.assertIn('resource "google_scc_management_organization_security_health_analytics_custom_module" "org_prod_bq_cmek"', mod_main)
        self.assertRegex(mod_main, r"target_resource\s*=\s*local\.parent_target_resource")
        self.assertIn('resource "google_scc_v2_project_scc_big_query_export" "project_active_findings"', mod_main)
        self.assertIn('resource "google_scc_v2_project_notification_config" "project_high_critical"', mod_main)
        self.assertIn('resource "google_scc_management_project_security_health_analytics_custom_module" "project_prod_bq_cmek"', mod_main)
        self.assertIn('resource "google_scc_management_organization_event_threat_detection_custom_module" "this"', mod_main)
        self.assertIn('push_config', mod_main)

        script = REPO_ROOT / "scripts" / "verify-scc-detectors.sh"
        self.assertTrue(script.is_file())
        self.assertTrue(script.stat().st_mode & stat.S_IXUSR)
        self.assertEqual(subprocess.run(["bash", "-n", str(script)], check=False).returncode, 0)

        dry_proj = subprocess.run(
            [str(script), "--project", "demo-proj-01", "--dry-run"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(dry_proj.returncode, 0, dry_proj.stderr)
        for svc in (
            "EVENT_THREAT_DETECTION",
            "CONTAINER_THREAT_DETECTION",
            "VIRTUAL_MACHINE_THREAT_DETECTION",
            "CLOUD_RUN_THREAT_DETECTION",
        ):
            self.assertIn(svc, dry_proj.stdout)

        bad_res = subprocess.run([str(script)], capture_output=True, text=True, check=False)
        self.assertEqual(bad_res.returncode, 2)


if __name__ == "__main__":
    unittest.main()
