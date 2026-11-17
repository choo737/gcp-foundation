"""Verify 4-Pillar Landing Zone updates (FinOps, Backup & DR, Cloud NGFW, and SCC)."""

from pathlib import Path
import re
import stat
import subprocess
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent


class FourPillarsTest(unittest.TestCase):
    """Validate FinOps, Backup/DR, Cloud NGFW layering, and BigQuery DR controls."""

    def test_pillar1_finops_dedicated_project_us_export_and_multi_budgets(self) -> None:
        org_vars = (REPO_ROOT / "foundation" / "01-org-governance" / "variables.tf").read_text(encoding="utf-8")
        org_main = (REPO_ROOT / "foundation" / "01-org-governance" / "main.tf").read_text(encoding="utf-8")
        org_outs = (REPO_ROOT / "foundation" / "01-org-governance" / "outputs.tf").read_text(encoding="utf-8")

        self.assertRegex(org_vars, r'variable\s+"create_dedicated_finops_project"[\s\S]*?default\s*=\s*true')
        self.assertIn('module "finops_project"', org_main)
        self.assertIn("-cmn-finops", org_main)
        self.assertIn('output "finops_project_id"', org_outs)

        finops_vars = (REPO_ROOT / "modules" / "foundation" / "finops-governance" / "variables.tf").read_text(encoding="utf-8")
        finops_main = (REPO_ROOT / "modules" / "foundation" / "finops-governance" / "main.tf").read_text(encoding="utf-8")

        self.assertRegex(finops_vars, r'variable\s+"billing_export_location"[\s\S]*?default\s*=\s*"US"')
        for var_name in (
            "finops_project_id",
            "alert_email_addresses",
            "environment_budgets",
            "environment_folder_ids",
            "workload_budgets",
            "budget_thresholds",
            "enable_forecasted_threshold",
            "disable_default_iam_recipients",
        ):
            self.assertIn(f'variable "{var_name}"', finops_vars)

        self.assertIn('resource "google_monitoring_notification_channel" "budget_email"', finops_main)
        self.assertIn('resource "google_billing_budget" "environment"', finops_main)
        self.assertIn('resource "google_billing_budget" "workload"', finops_main)
        self.assertIn("<= 5", finops_main)

    def test_pillar2_backup_dr_soft_delete_dual_region_and_bq_dr(self) -> None:
        bdr_main = (REPO_ROOT / "modules" / "foundation" / "backup-dr" / "main.tf").read_text(encoding="utf-8")
        bdr_vars = (REPO_ROOT / "modules" / "foundation" / "backup-dr" / "variables.tf").read_text(encoding="utf-8")

        self.assertIn('resource "google_backup_dr_backup_vault" "primary"', bdr_main)
        self.assertIn('resource "google_backup_dr_backup_plan" "gce"', bdr_main)
        self.assertIn('resource "google_backup_dr_backup_plan" "cloudsql"', bdr_main)
        self.assertIn("compute.googleapis.com/Instance", bdr_main)
        self.assertIn("sqladmin.googleapis.com/Instance", bdr_main)
        self.assertRegex(bdr_vars, r'variable\s+"backup_time_zone"[\s\S]*?default\s*=\s*"Asia/Kuala_Lumpur"')

        org_main = (REPO_ROOT / "foundation" / "01-org-governance" / "main.tf").read_text(encoding="utf-8")
        org_outs = (REPO_ROOT / "foundation" / "01-org-governance" / "outputs.tf").read_text(encoding="utf-8")
        self.assertIn('module "backup_project"', org_main)
        self.assertIn("-cmn-backup", org_main)
        self.assertIn('module "backup_dr"', org_main)
        self.assertIn('output "backup_project_id"', org_outs)
        self.assertIn('output "backup_vault_id"', org_outs)

        for root in ("foundation/00-bootstrap", "data/sandbox", "data/enterprise/01-platform"):
            main_text = (REPO_ROOT / root / "main.tf").read_text(encoding="utf-8")
            vars_text = (REPO_ROOT / root / "variables.tf").read_text(encoding="utf-8")
            self.assertIn("soft_delete_policy", main_text)
            self.assertRegex(vars_text, r'variable\s+"soft_delete_retention_seconds"[\s\S]*?default\s*=\s*1209600')

        plat_main = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf").read_text(encoding="utf-8")
        plat_vars = (REPO_ROOT / "data" / "enterprise" / "01-platform" / "variables.tf").read_text(encoding="utf-8")
        self.assertRegex(plat_vars, r'variable\s+"enable_dr_datasets"[\s\S]*?default\s*=\s*false')
        self.assertIn("custom_placement_config", plat_main)
        self.assertIn("dual_region_data_locations", plat_main)

        res_main = (REPO_ROOT / "modules" / "data" / "bigquery-reservations" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("secondary_location", res_main)
        self.assertIn("ENTERPRISE_PLUS", res_main)

        script = REPO_ROOT / "scripts" / "configure-bq-dr-replica.sh"
        self.assertTrue(script.is_file())
        self.assertTrue(script.stat().st_mode & stat.S_IXUSR)
        self.assertEqual(subprocess.run(["bash", "-n", str(script)], check=False).returncode, 0)

        dry = subprocess.run(
            [
                str(script),
                "--project",
                "demo-proj-01",
                "--dataset",
                "ent_gold_mart",
                "--replica-location",
                "asia-southeast2",
                "--dry-run",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertIn("ALTER SCHEMA `demo-proj-01.ent_gold_mart` ADD REPLICA `asia-southeast2`", dry.stdout)

        bad = subprocess.run([str(script), "--project", ""], capture_output=True, text=True, check=False)
        self.assertEqual(bad.returncode, 2)

    def test_pillar3_cloud_ngfw_layering_secure_tags_and_enterprise_opt_in(self) -> None:
        net_main = (REPO_ROOT / "modules" / "foundation" / "network-security" / "main.tf").read_text(encoding="utf-8")
        net_vars = (REPO_ROOT / "modules" / "foundation" / "network-security" / "variables.tf").read_text(encoding="utf-8")
        stage_main = (REPO_ROOT / "foundation" / "02-security-network" / "main.tf").read_text(encoding="utf-8")

        self.assertIn('resource "google_compute_firewall_policy" "folder"', net_main)
        self.assertIn('resource "google_compute_firewall_policy_association" "folder"', net_main)
        self.assertIn("src_threat_intelligences", net_main)
        self.assertIn("dest_threat_intelligences", net_main)
        self.assertIn("35.235.240.0/20", net_main)
        self.assertIn('action          = "goto_next"', net_main)
        self.assertIn('resource "google_tags_tag_key" "tier"', net_main)
        self.assertIn('purpose     = "GCE_FIREWALL"', net_main)
        self.assertIn("target_secure_tags", net_main)
        self.assertIn("dest_fqdns", net_main)
        self.assertIn('resource "google_network_security_firewall_endpoint" "ngfw"', net_main)
        self.assertIn('resource "google_network_security_firewall_endpoint_association" "ngfw"', net_main)
        self.assertIn('resource "google_network_security_security_profile" "threat_prevention"', net_main)
        self.assertIn('resource "google_network_security_security_profile_group" "ngfw"', net_main)
        self.assertIn('action                 = "apply_security_profile_group"', net_main)
        self.assertRegex(net_vars, r'variable\s+"enable_ngfw_enterprise"[\s\S]*?default\s*=\s*false')
        self.assertIn('"networksecurity.googleapis.com"', stage_main)


if __name__ == "__main__":
    unittest.main()
