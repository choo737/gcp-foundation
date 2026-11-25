"""Verify 7-team RBAC, SecOps/AR, department subnets, apps/enterprise, auto_unique_suffix, and docs."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent


class SevenTeamAndAppsTest(unittest.TestCase):
    """Validate multi-department landing zone, app workload factory, linker, and deterministic AI docs."""

    def test_folder_hierarchy_ai_and_app_subfolders_and_org_governance_controls(self) -> None:
        fh_main = (REPO_ROOT / "modules/foundation/folder-hierarchy/main.tf").read_text(encoding="utf-8")
        fh_outs = (REPO_ROOT / "modules/foundation/folder-hierarchy/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_folder" "env_ai"', fh_main)
        self.assertIn('resource "google_folder" "env_app"', fh_main)
        self.assertIn('output "environment_ai_folder_ids"', fh_outs)
        self.assertIn('output "environment_app_folder_ids"', fh_outs)

        org_vars = (REPO_ROOT / "foundation/01-org-governance/variables.tf").read_text(encoding="utf-8")
        org_main = (REPO_ROOT / "foundation/01-org-governance/main.tf").read_text(encoding="utf-8")
        org_outs = (REPO_ROOT / "foundation/01-org-governance/outputs.tf").read_text(encoding="utf-8")

        for var_name in (
            "create_dedicated_secops_project",
            "enable_shared_artifact_registry",
            "department_budgets",
            "finops_billing_export_table_name",
            "auto_unique_suffix",
        ):
            self.assertIn(f'variable "{var_name}"', org_vars)

        self.assertIn('module "secops_project"', org_main)
        self.assertIn("prj-coe-secops", org_main)
        self.assertIn("audit_project_id           = local.effective_secops_project", org_main)
        self.assertIn('resource "google_artifact_registry_repository" "golden_images"', org_main)
        self.assertIn("gcp-sa-artifactregistry.iam.gserviceaccount.com", org_main)
        self.assertIn("roles/artifactregistry.repoAdmin", org_main)

        for out_name in (
            "environment_ai_folder_ids",
            "environment_app_folder_ids",
            "secops_project_id",
            "shared_artifact_registry_id",
            "department_budget_names",
        ):
            self.assertIn(f'output "{out_name}"', org_outs)

    def test_finops_tags_department_budgets_view_and_seven_team_rbac(self) -> None:
        finops_main = (REPO_ROOT / "modules/foundation/finops-governance/main.tf").read_text(encoding="utf-8")
        finops_vars = (REPO_ROOT / "modules/foundation/finops-governance/variables.tf").read_text(encoding="utf-8")
        for tag_key in ("platform", "shared", "data", "ai", "app", "security", "network", "uat"):
            self.assertIn(f"{tag_key} ", finops_main)
        self.assertIn('variable "department_budgets"', finops_vars)
        self.assertIn('resource "google_billing_budget" "department"', finops_main)
        self.assertIn('table_id            = "v_finops_department_spend"', finops_main)
        self.assertIn("roles/billing.costsManager", finops_main)

        lg_vars = (REPO_ROOT / "modules/foundation/logging-guardrails/variables.tf").read_text(encoding="utf-8")
        lg_main = (REPO_ROOT / "modules/foundation/logging-guardrails/main.tf").read_text(encoding="utf-8")
        for group_key in ("cloudops_admins", "finops_admins", "security_admins", "secops_analysts"):
            self.assertIn(f'"{group_key}"', lg_vars)
        self.assertIn("roles/resourcemanager.folderViewer", lg_main)
        self.assertIn("roles/orgpolicy.policyViewer", lg_main)
        self.assertIn("roles/cloudkms.viewer", lg_main)

        scc_main = (REPO_ROOT / "modules/foundation/scc-secops/main.tf").read_text(encoding="utf-8")
        self.assertIn("secops_analysts_bq_viewer", scc_main)
        self.assertIn("secops_analysts_bq_job_user", scc_main)

    def test_bootstrap_network_and_data_platform_extensions(self) -> None:
        boot_vars = (REPO_ROOT / "foundation/00-bootstrap/variables.tf").read_text(encoding="utf-8")
        boot_main = (REPO_ROOT / "foundation/00-bootstrap/main.tf").read_text(encoding="utf-8")
        boot_outs = (REPO_ROOT / "foundation/00-bootstrap/outputs.tf").read_text(encoding="utf-8")
        for key in ("tf_app_ci", "secops_ci", "finops_ci"):
            self.assertIn(f'"{key}"', boot_vars)
        self.assertIn('tf_app_ci       = "apps/"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_app_viewer"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_app_prefix_admin"', boot_main)
        self.assertIn('output "tf_app_ci_sa_email"', boot_outs)

        net_mod_main = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        net_mod_outs = (REPO_ROOT / "modules/foundation/network-security/outputs.tf").read_text(encoding="utf-8")
        net_stage_main = (REPO_ROOT / "foundation/02-security-network/main.tf").read_text(encoding="utf-8")
        net_stage_outs = (REPO_ROOT / "foundation/02-security-network/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_compute_subnetwork" "department"', net_mod_main)
        for out_name in ("department_subnet_ids", "data_subnet_id", "ai_subnet_id", "app_subnet_id"):
            self.assertIn(f'output "{out_name}"', net_mod_outs)
            self.assertIn(f'output "{out_name}"', net_stage_outs)
        self.assertIn("roles/compute.networkAdmin", net_stage_main)
        self.assertIn("roles/dns.admin", net_stage_main)
        self.assertIn("roles/cloudkms.viewer", net_stage_main)

        plat_vars = (REPO_ROOT / "data/enterprise/01-platform/variables.tf").read_text(encoding="utf-8")
        plat_main = (REPO_ROOT / "data/enterprise/01-platform/main.tf").read_text(encoding="utf-8")
        self.assertIn('variable "env_groups"', plat_vars)
        self.assertIn("env_group_nonprod_bq_job_user", plat_main)
        self.assertIn('var.environment != "prod"', plat_main)

        ds_vars = (REPO_ROOT / "data/enterprise/03-data-science/variables.tf").read_text(encoding="utf-8")
        ds_main = (REPO_ROOT / "data/enterprise/03-data-science/main.tf").read_text(encoding="utf-8")
        for var_name in ("environment_ai_folder_ids", "ai_folder_id", "ai_admins_group", "env_groups"):
            self.assertIn(f'variable "{var_name}"', ds_vars)
        self.assertIn('"cost_center.ai"', ds_main)
        self.assertIn("ai_admins_ds_exp_aiplatform_viewer", ds_main)

    def test_workload_factory_and_apps_enterprise_contracts(self) -> None:
        wf_vars = (REPO_ROOT / "modules/app/workload-factory/variables.tf").read_text(encoding="utf-8")
        wf_main = (REPO_ROOT / "modules/app/workload-factory/main.tf").read_text(encoding="utf-8")
        apps_main = (REPO_ROOT / "apps/enterprise/main.tf").read_text(encoding="utf-8")

        self.assertIn('^[a-z][a-z0-9-]{0,4}[a-z0-9]$', wf_vars)
        self.assertIn('resource "google_folder" "app_unit"', wf_main)
        self.assertIn('module "app_project"', wf_main)
        self.assertIn('resource "google_compute_shared_vpc_service_project" "app"', wf_main)
        self.assertIn('resource "google_compute_subnetwork_iam_member" "cloudrun_network_user"', wf_main)
        self.assertIn('resource "google_compute_subnetwork_iam_member" "gke_cloudservices_network_user"', wf_main)
        self.assertIn('resource "google_compute_subnetwork_iam_member" "gke_robot_network_user"', wf_main)
        self.assertIn('roles/container.hostServiceAgentUser', wf_main)
        self.assertIn('resource "google_kms_crypto_key_iam_member" "app_cmek"', wf_main)
        self.assertIn('resource "google_artifact_registry_repository_iam_member" "shared_golden_reader"', wf_main)
        self.assertIn('var.environment != "prod"', wf_main)
        self.assertIn('source = "../../modules/app/workload-factory"', apps_main)
        self.assertIn('startswith(trimspace(each.value.display_name), "fldr-") ? trimspace(each.value.display_name) : "fldr-${var.environment}-${each.key}"', wf_main)

        # 30-char max project ID check: 'prj-' (4) + 4-char env4 + '-app-' (5) + 6-char app_key + '-' (1) + 4-char suffix = 24 <= 30.
        self.assertLessEqual(4 + 4 + len("-app-") + 6 + 1 + 4, 30)

    def test_link_stages_uat_apps_and_department_subnet_remapping(self) -> None:
        script_path = REPO_ROOT / "scripts/link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            bin_dir.mkdir()
            src_net = tmp_path / "foundation/02-security-network"
            dst_apps = tmp_path / "apps/enterprise"
            dst_ds = tmp_path / "data/enterprise/03-data-science"
            dst_plat = tmp_path / "data/enterprise/01-platform"
            for d in (src_net, dst_apps, dst_ds, dst_plat):
                d.mkdir(parents=True)

            for dst in (dst_apps, dst_ds, dst_plat):
                (dst / "variables.tf").write_text(
                    'variable "environment" {\n  type = string\n}\n'
                    'variable "subnet_id" {\n  type = string\n}\n'
                    'variable "shared_artifact_registry_id" {\n  type = string\n}\n'
                    'variable "environment_app_folder_ids" {\n  type = map(string)\n}\n',
                    encoding="utf-8",
                )

            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({\n"
                "    'subnet_id': {'value': 'projects/n/regions/r/subnetworks/primary', 'sensitive': False},\n"
                "    'data_subnet_id': {'value': 'projects/n/regions/r/subnetworks/data-snet', 'sensitive': False},\n"
                "    'ai_subnet_id': {'value': 'projects/n/regions/r/subnetworks/ai-snet', 'sensitive': False},\n"
                "    'app_subnet_id': {'value': 'projects/n/regions/r/subnetworks/app-snet', 'sensitive': False},\n"
                "    'shared_artifact_registry_id': {'value': 'projects/a/locations/r/repositories/g', 'sensitive': False},\n"
                "    'environment_app_folder_ids': {'value': {'uat': 'folders/777'}, 'sensitive': False},\n"
                "}))\n",
                encoding="utf-8",
            )
            tf_shim.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"

            for dst, expected_sub in (
                (dst_apps, "projects/n/regions/r/subnetworks/app-snet"),
                (dst_ds, "projects/n/regions/r/subnetworks/ai-snet"),
                (dst_plat, "projects/n/regions/r/subnetworks/data-snet"),
            ):
                res = subprocess.run(
                    [str(script_path), "--env", "uat", str(src_net), str(dst)],
                    env=env,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res.returncode, 0, res.stderr)
                linked = json.loads((dst / "00_linked.auto.tfvars.json").read_text(encoding="utf-8"))
                self.assertEqual(linked["environment"], "uat")
                self.assertEqual(linked["subnet_id"], expected_sub)
                self.assertEqual(linked["shared_artifact_registry_id"], "projects/a/locations/r/repositories/g")
                self.assertEqual(linked["environment_app_folder_ids"], {"uat": "folders/777"})

        deploy_wf = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("- uat", deploy_wf)
        self.assertIn("- apps/enterprise", deploy_wf)
        self.assertIn("GCP_APP_WIF_SA", deploy_wf)

    def test_auto_unique_suffix_and_acronym_rule_and_seven_chapters_doc(self) -> None:
        roots_with_auto_suffix = (
            "foundation/00-bootstrap",
            "foundation/01-org-governance",
            "foundation/02-security-network",
            "data/sandbox",
            "data/enterprise/01-platform",
            "data/enterprise/03-data-science",
            "apps/enterprise",
        )
        for root in roots_with_auto_suffix:
            vars_text = (REPO_ROOT / root / "variables.tf").read_text(encoding="utf-8")
            ex_text = (REPO_ROOT / root / "terraform.tfvars.example").read_text(encoding="utf-8")
            with self.subTest(root=root):
                self.assertRegex(vars_text, r'variable\s+"auto_unique_suffix"[\s\S]*?default\s*=\s*true')
                self.assertIn("auto_unique_suffix", ex_text)
                if root != "data/sandbox":
                    self.assertIn('^[a-z0-9]([a-z0-9-]{0,2}[a-z0-9])?$', vars_text)

        for doc_rel in (
            "QUESTIONNAIRE.md",
            "AGENTS.md",
            "CLAUDE.md",
            ".agents/skills/setup-customer-foundation/SKILL.md",
        ):
            doc_text = (REPO_ROOT / doc_rel).read_text(encoding="utf-8")
            with self.subTest(doc=doc_rel):
                self.assertIn("auto_unique_suffix", doc_text)
                self.assertIn("Bhd", doc_text)
                self.assertIn("Holdings", doc_text)

        sec_doc = (REPO_ROOT / "docs/03-security-foundations-blueprint.md").read_text(encoding="utf-8")
        for heading in (
            "## 1. Authentication and Authorization",
            "## 2. Organization Structure",
            "## 3. Networking",
            "## 4. Detective Controls",
            "## 5. Preventative Controls",
            "## 6. Deployment Methodology",
            "## 7. Operations Best Practices",
        ):
            self.assertIn(heading, sec_doc)

        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
            with tempfile.TemporaryDirectory() as tmp:
                tmp_repo = Path(tmp) / "repo"
                shutil.copytree(REPO_ROOT / "modules", tmp_repo / "modules")
                shutil.copytree(REPO_ROOT / "apps", tmp_repo / "apps")
                apps_dir = tmp_repo / "apps" / "enterprise"
                versions_path = apps_dir / "versions.tf"
                versions_path.write_text(
                    versions_path.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                    encoding="utf-8",
                )
                shutil.rmtree(apps_dir / ".terraform", ignore_errors=True)
                cached = REPO_ROOT / "apps" / "enterprise" / ".terraform" / "providers"
                init_cmd = [tf_bin, f"-chdir={apps_dir}", "init", "-input=false"]
                if cached.is_dir():
                    init_cmd.append(f"-plugin-dir={cached}")
                self.assertEqual(subprocess.run(init_cmd, capture_output=True, text=True, check=False).returncode, 0)

                (apps_dir / "auto_test.auto.tfvars.json").write_text(
                    json.dumps({
                        "billing_account": "000000-000000-000000",
                        "prefix": "abcdefgh",
                        "project_suffix": "",
                        "auto_unique_suffix": True,
                        "environment": "prod",
                        "app_folder_id": "folders/123456",
                        "applications": {"portal": {"display_name": "Portal"}},
                    }),
                    encoding="utf-8",
                )
                res = subprocess.run(
                    [tf_bin, f"-chdir={apps_dir}", "console"],
                    input="\"${local.project_env_prefix}-app-portal${local.project_suffix_tail}\"\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res.returncode, 0, res.stderr)
                pid = res.stdout.strip().splitlines()[-1].strip('"')
                self.assertRegex(pid, r"^prj-prod-app-portal-[0-9a-f]{4}$")
                self.assertLessEqual(len(pid), 30)

                wf_dir = tmp_repo / "modules" / "app" / "workload-factory"
                wf_init = [tf_bin, f"-chdir={wf_dir}", "init", "-input=false"]
                if cached.is_dir():
                    wf_init.append(f"-plugin-dir={cached}")
                self.assertEqual(subprocess.run(wf_init, capture_output=True, text=True, check=False).returncode, 0)
                (wf_dir / "wf_test.auto.tfvars.json").write_text(
                    json.dumps({
                        "billing_account": "000000-000000-000000",
                        "prefix": "abcdefgh",
                        "project_suffix": pid.rsplit("-", 1)[-1],
                        "environment": "prod",
                        "app_folder_id": "folders/123456",
                        "applications": {"portal": {"display_name": "Portal"}},
                    }),
                    encoding="utf-8",
                )
                wf_res = subprocess.run(
                    [tf_bin, f"-chdir={wf_dir}", "console"],
                    input="local.app_project_ids[\"portal\"]\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(wf_res.returncode, 0, wf_res.stderr)
                self.assertEqual(wf_res.stdout.strip().splitlines()[-1].strip('"'), pid)

                (apps_dir / "auto_test.auto.tfvars.json").write_text(
                    json.dumps({
                        "billing_account": "000000-000000-000000",
                        "prefix": "abcdefgh",
                        "project_suffix": "12345",
                        "environment": "prod",
                        "app_folder_id": "folders/123456",
                        "applications": {"portal": {"display_name": "Portal"}},
                    }),
                    encoding="utf-8",
                )
                bad_suffix_res = subprocess.run(
                    [tf_bin, f"-chdir={apps_dir}", "console"],
                    input="var.project_suffix\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", bad_suffix_res.stderr)
                self.assertIn("1-4 lowercase alphanumeric", bad_suffix_res.stderr)

    def test_pass14_uat_tier_and_wif_isolation(self) -> None:
        multi_env_roots = (
            "foundation/02-security-network",
            "data/enterprise/01-platform",
            "data/enterprise/02-governance-ops",
            "data/enterprise/03-data-science",
            "apps/enterprise",
        )
        for root in multi_env_roots:
            uat_ex = REPO_ROOT / root / "envs" / "uat.tfvars.example"
            with self.subTest(root=root):
                self.assertTrue(uat_ex.is_file(), f"Missing {uat_ex}")
                self.assertIn('= "uat"', uat_ex.read_text(encoding="utf-8"))

        for doc_name in ("AGENTS.md", "CLAUDE.md"):
            self.assertIn("envs/{dev,uat,prod}.tfvars.example", (REPO_ROOT / doc_name).read_text(encoding="utf-8"))

        boot_vars = (REPO_ROOT / "foundation/00-bootstrap/variables.tf").read_text(encoding="utf-8")
        boot_main = (REPO_ROOT / "foundation/00-bootstrap/main.tf").read_text(encoding="utf-8")
        boot_ex = (REPO_ROOT / "foundation/00-bootstrap/terraform.tfvars.example").read_text(encoding="utf-8")
        org_ex = (REPO_ROOT / "foundation/01-org-governance/terraform.tfvars.example").read_text(encoding="utf-8")
        self.assertIn("uat", boot_vars)
        self.assertIn("uat", boot_ex)
        self.assertIn("uat", org_ex)

        # P0-2 + SF-4: per_stage creates tf_app_ci, allows per-env apps-enterprise-outputs.json, and wires secops_ci/finops_ci.
        self.assertRegex(
            boot_main,
            r'include_tf_app_ci\s*=\s*\(\s*var\.foundation_sa_mode\s*==\s*"per_stage"',
        )
        self.assertIn('resource.name.endsWith(\\"/apps-enterprise-outputs.json\\")', boot_main)
        self.assertIn('secops_ci       = "foundation/01-org-governance/"', boot_main)
        self.assertIn('finops_ci       = "foundation/01-org-governance/"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_shared_viewer"', boot_main)
        self.assertIn('resource "google_storage_bucket_iam_member" "iac_outputs_shared_prefix_admin"', boot_main)

        # P0-1 + P0-2 + P0-4 in terraform-deploy.yml.
        deploy_wf = (REPO_ROOT / ".github/workflows/terraform-deploy.yml").read_text(encoding="utf-8")
        self.assertIn("deploy-uat:", deploy_wf)
        self.assertIn("environment: uat", deploy_wf)
        self.assertIn("--env uat", deploy_wf)
        self.assertIn("envs/uat.tfvars", deploy_wf)
        self.assertNotIn("inputs.stage == 'apps/enterprise' && (vars.GCP_APP_WIF_SA || vars.GCP_DATA_PLAT_WIF_SA)", deploy_wf)
        self.assertNotIn("inputs.stage == 'apps/enterprise' && (vars.GCP_APP_WIF_SA != '' || vars.GCP_DATA_PLAT_WIF_SA != '')", deploy_wf)
        self.assertIn("inputs.stage == 'apps/enterprise' && vars.GCP_APP_WIF_SA", deploy_wf)

        # P0-4: 01-platform-outputs.json comes after 03-data-science-outputs.json so subnet_id stays data-snet.
        for merge_line in [ln for ln in deploy_wf.splitlines() if "foundation-outputs.json" in ln and "--from-gcs" in ln]:
            if "03-data-science-outputs.json" in merge_line:
                self.assertLess(
                    merge_line.index("03-data-science-outputs.json"),
                    merge_line.index("01-platform-outputs.json"),
                    f"Expected 03-data-science before 01-platform in: {merge_line}",
                )

    def test_pass14_finops_ancestors_labels_ar_gke_vpc_sc_and_suffix(self) -> None:
        # P0-3: department_budget_ancestors + v_finops_department_spend SQL + cost_center/environment labels.
        fin_vars = (REPO_ROOT / "modules/foundation/finops-governance/variables.tf").read_text(encoding="utf-8")
        fin_main = (REPO_ROOT / "modules/foundation/finops-governance/main.tf").read_text(encoding="utf-8")
        self.assertIn('variable "department_budget_ancestors"', fin_vars)
        self.assertIn("resource_ancestors", fin_main)
        self.assertIn("UNNEST(tags)", fin_main)
        self.assertIn("ENDS_WITH(t.key, '/cost_center')", fin_main)
        self.assertIn("UNNEST(project.labels)", fin_main)

        org_main = (REPO_ROOT / "foundation/01-org-governance/main.tf").read_text(encoding="utf-8")
        org_outs = (REPO_ROOT / "foundation/01-org-governance/outputs.tf").read_text(encoding="utf-8")
        self.assertIn("department_budget_ancestors =", org_main)
        self.assertIn("environment_data_platform_folder_ids", org_main)
        self.assertIn("environment_ai_folder_ids", org_main)
        self.assertIn("environment_app_folder_ids", org_main)
        self.assertIn("project       = local.effective_secops_project", org_main)
        self.assertIn("google_project_service_identity.secops_artifactregistry", org_main)
        self.assertIn('output "golden_images_project_number"', org_outs)
        self.assertIn('output "auto_unique_suffix"', org_outs)

        # Exact 24 declared variables preserved in apps/enterprise/variables.tf.
        apps_vars_text = (REPO_ROOT / "apps/enterprise/variables.tf").read_text(encoding="utf-8")
        apps_declared_vars = re.findall(r'^\s*variable\s+"([A-Za-z0-9_]+)"\s*\{', apps_vars_text, re.MULTILINE)
        self.assertEqual(
            apps_declared_vars,
            [
                "applications",
                "prefix",
                "project_suffix",
                "auto_unique_suffix",
                "environment",
                "region",
                "billing_account",
                "app_folder_id",
                "environment_app_folder_ids",
                "deletion_protection",
                "project_deletion_policy",
                "shared_vpc_host_project_id",
                "vpc_id",
                "subnet_id",
                "kms_key_id",
                "manage_kms_iam",
                "shared_artifact_registry_id",
                "app_admins_group",
                "finops_tag_value_ids",
                "vpc_sc_perimeter_name",
                "enforce_vpc_sc",
                "manage_vpc_sc",
                "propagation_wait_seconds",
                "labels",
            ],
        )

        # P0-5: app_runtime SA, GKE AR reader + compute SA, secondary ranges, VPC-SC AR egress.
        wf_main = (REPO_ROOT / "modules/app/workload-factory/main.tf").read_text(encoding="utf-8")
        wf_outs = (REPO_ROOT / "modules/app/workload-factory/outputs.tf").read_text(encoding="utf-8")
        apps_outs = (REPO_ROOT / "apps/enterprise/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_service_account" "app_runtime"', wf_main)
        self.assertIn("sa-${each.key}-rt", wf_main)
        self.assertIn('resource "google_service_account" "gke_node"', wf_main)
        self.assertIn("sa-${each.key}-gke-node", wf_main)
        self.assertNotIn("-compute@developer.gserviceaccount.com", wf_main)
        self.assertIn('resource "google_project_service_identity" "artifactregistry"', wf_main)
        self.assertIn('resource "google_project_service_identity" "compute"', wf_main)
        self.assertIn("@gcp-sa-artifactregistry.iam.gserviceaccount.com", wf_main)
        self.assertIn('output "app_runtime_sa_emails"', wf_outs)
        self.assertIn('output "app_runtime_sa_emails"', apps_outs)

        net_mod_vars = (REPO_ROOT / "modules/foundation/network-security/variables.tf").read_text(encoding="utf-8")
        net_mod_main = (REPO_ROOT / "modules/foundation/network-security/main.tf").read_text(encoding="utf-8")
        net_mod_outs = (REPO_ROOT / "modules/foundation/network-security/outputs.tf").read_text(encoding="utf-8")
        net_stg_vars = (REPO_ROOT / "foundation/02-security-network/variables.tf").read_text(encoding="utf-8")
        net_stg_outs = (REPO_ROOT / "foundation/02-security-network/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('variable "department_subnet_secondary_ranges"', net_mod_vars)
        self.assertIn('variable "department_subnet_secondary_ranges"', net_stg_vars)
        self.assertIn('variable "vpc_sc_secops_project_number"', net_mod_vars)
        self.assertIn('variable "secops_project_number"', net_stg_vars)
        self.assertIn('secondary_ip_range', net_mod_main)
        self.assertIn('cidrsubnet("100.64.0.0/12", 4, idx)', net_mod_main)
        self.assertIn('cidrsubnet("100.80.0.0/16", 4, idx)', net_mod_main)
        self.assertIn('secops-golden-ar-egress', net_mod_main)
        self.assertGreaterEqual(net_mod_main.count('service_name = "artifactregistry.googleapis.com"'), 4)
        self.assertIn('output "department_subnet_secondary_range_names"', net_mod_outs)
        self.assertIn('output "department_subnet_secondary_range_names"', net_stg_outs)

        # SF-1, SF-2, SF-3 checks.
        plat_vars = (REPO_ROOT / "data/enterprise/01-platform/variables.tf").read_text(encoding="utf-8")
        plat_main = (REPO_ROOT / "data/enterprise/01-platform/main.tf").read_text(encoding="utf-8")
        plat_outs = (REPO_ROOT / "data/enterprise/01-platform/outputs.tf").read_text(encoding="utf-8")
        ds_vars = (REPO_ROOT / "data/enterprise/03-data-science/variables.tf").read_text(encoding="utf-8")
        ds_main = (REPO_ROOT / "data/enterprise/03-data-science/main.tf").read_text(encoding="utf-8")
        ds_outs = (REPO_ROOT / "data/enterprise/03-data-science/outputs.tf").read_text(encoding="utf-8")
        net_stg_main = (REPO_ROOT / "foundation/02-security-network/main.tf").read_text(encoding="utf-8")

        for stg_text in (plat_vars, ds_vars):
            self.assertIn('variable "shared_artifact_registry_id"', stg_text)
        for stg_main in (plat_main, ds_main):
            self.assertIn('resource "google_artifact_registry_repository_iam_member" "shared_golden_reader"', stg_main)
        for stg_main in (net_stg_main, plat_main, ds_main, wf_main):
            self.assertIn('"environment.uat"', stg_main)
        for stg_outs in (net_stg_outs, plat_outs, ds_outs):
            self.assertIn("value       = local.effective_project_suffix", stg_outs)

        # P0-4 GCS merge simulation + SF-1 terraform console suffix propagation check.
        script_path = REPO_ROOT / "scripts/link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            gcs_store = tmp_path / "gcs_store"
            bin_dir.mkdir()
            gcs_store.mkdir()

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

            (gcs_store / "bkt" / "shared").mkdir(parents=True)
            (gcs_store / "bkt" / "uat").mkdir(parents=True)
            (gcs_store / "bkt" / "shared" / "01-org-governance-outputs.json").write_text(
                json.dumps({"auto_unique_suffix": True, "environment": "shared"}), encoding="utf-8"
            )
            (gcs_store / "bkt" / "uat" / "01-platform-outputs.json").write_text(
                json.dumps({"subnet_id": "projects/n/regions/r/subnetworks/data-snet", "project_suffix": "a1b2"}), encoding="utf-8"
            )
            (gcs_store / "bkt" / "uat" / "02-governance-ops-outputs.json").write_text(
                json.dumps({"dataform_repository_name": "ent-medallion"}), encoding="utf-8"
            )
            (gcs_store / "bkt" / "uat" / "03-data-science-outputs.json").write_text(
                json.dumps({"subnet_id": "projects/n/regions/r/subnetworks/ai-snet"}), encoding="utf-8"
            )
            (gcs_store / "bkt" / "uat" / "02-security-network-outputs.json").write_text(
                json.dumps({
                    "subnet_id": "projects/n/regions/r/subnetworks/base-snet",
                    "data_subnet_id": "projects/n/regions/r/subnetworks/data-snet",
                    "ai_subnet_id": "projects/n/regions/r/subnetworks/ai-snet",
                    "app_subnet_id": "projects/n/regions/r/subnetworks/app-snet",
                    "project_suffix": "a1b2",
                }),
                encoding="utf-8",
            )

            merge_res = subprocess.run(
                [
                    str(script_path),
                    "--env",
                    "uat",
                    "--export-gcs",
                    "gs://bkt/foundation-outputs.json",
                    "--from-gcs",
                    "gs://bkt/shared/01-org-governance-outputs.json",
                    "gs://bkt/02-security-network-outputs.json",
                    "gs://bkt/03-data-science-outputs.json",
                    "gs://bkt/01-platform-outputs.json",
                    "gs://bkt/02-governance-ops-outputs.json",
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(merge_res.returncode, 0, merge_res.stderr)
            merged = json.loads((gcs_store / "bkt" / "uat" / "foundation-outputs.json").read_text(encoding="utf-8"))
            self.assertEqual(merged["subnet_id"], "projects/n/regions/r/subnetworks/data-snet")
            self.assertEqual(merged["data_subnet_id"], "projects/n/regions/r/subnetworks/data-snet")
            self.assertEqual(merged["ai_subnet_id"], "projects/n/regions/r/subnetworks/ai-snet")
            self.assertEqual(merged["app_subnet_id"], "projects/n/regions/r/subnetworks/app-snet")
            self.assertEqual(merged["project_suffix"], "a1b2")

        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
            expected_uat_suffix = hashlib.sha256(b"000000-000000-000000-ent-uat").hexdigest()[:4]
            with tempfile.TemporaryDirectory() as tmp:
                tmp_repo = Path(tmp) / "repo"
                shutil.copytree(REPO_ROOT / "modules", tmp_repo / "modules")
                shutil.copytree(REPO_ROOT / "foundation", tmp_repo / "foundation")
                shutil.copytree(REPO_ROOT / "apps", tmp_repo / "apps")

                net_dir = tmp_repo / "foundation" / "02-security-network"
                net_versions = net_dir / "versions.tf"
                net_versions.write_text(
                    net_versions.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                    encoding="utf-8",
                )
                shutil.rmtree(net_dir / ".terraform", ignore_errors=True)
                net_cached = REPO_ROOT / "foundation" / "02-security-network" / ".terraform" / "providers"
                net_init = [tf_bin, f"-chdir={net_dir}", "init", "-input=false"]
                if net_cached.is_dir():
                    net_init.append(f"-plugin-dir={net_cached}")
                self.assertEqual(subprocess.run(net_init, capture_output=True, text=True, check=False).returncode, 0)

                (net_dir / "test_sec_ranges.auto.tfvars.json").write_text(
                    json.dumps({
                        "billing_account": "000000-000000-000000",
                        "prefix": "ent",
                        "environment": "uat",
                        "auto_unique_suffix": True,
                        "shared_infra_folder_id": "folders/123",
                        "department_subnet_cidrs": {
                            "data": "10.20.32.0/22",
                            "ai": "10.20.36.0/22",
                            "app": "10.20.40.0/22",
                        },
                    }),
                    encoding="utf-8",
                )
                res_net = subprocess.run(
                    [tf_bin, f"-chdir={net_dir}", "console"],
                    input='jsonencode({ suffix = local.effective_project_suffix, net_pid = local.network_project_id, ranges = module.network_security.department_subnet_secondary_range_names, pods0 = cidrsubnet("100.64.0.0/12", 4, 0), svc0 = cidrsubnet("100.80.0.0/16", 4, 0) })\n',
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res_net.returncode, 0, res_net.stderr)
                parsed_net = json.loads(json.loads(res_net.stdout.strip()))
                self.assertEqual(parsed_net["suffix"], expected_uat_suffix)
                self.assertEqual(parsed_net["net_pid"], f"prj-uat-network-{expected_uat_suffix}")
                self.assertEqual(parsed_net["pods0"], "100.64.0.0/16")
                self.assertEqual(parsed_net["svc0"], "100.80.0.0/20")
                self.assertEqual(parsed_net["ranges"]["app"], {"pods": "app-pods", "services": "app-services"})

                # Verify apps/enterprise inherits project_suffix when auto_unique_suffix is omitted.
                apps_dir = tmp_repo / "apps" / "enterprise"
                apps_versions = apps_dir / "versions.tf"
                apps_versions.write_text(
                    apps_versions.read_text(encoding="utf-8").replace('backend "gcs" {}', 'backend "local" {}'),
                    encoding="utf-8",
                )
                shutil.rmtree(apps_dir / ".terraform", ignore_errors=True)
                apps_cached = REPO_ROOT / "apps" / "enterprise" / ".terraform" / "providers"
                apps_init = [tf_bin, f"-chdir={apps_dir}", "init", "-input=false"]
                if apps_cached.is_dir():
                    apps_init.append(f"-plugin-dir={apps_cached}")
                self.assertEqual(subprocess.run(apps_init, capture_output=True, text=True, check=False).returncode, 0)

                (apps_dir / "00_linked.auto.tfvars.json").write_text(
                    json.dumps({
                        "billing_account": "000000-000000-000000",
                        "prefix": "ent",
                        "environment": "uat",
                        "project_suffix": expected_uat_suffix,
                        "app_folder_id": "folders/999",
                        "applications": {"portal": {"display_name": "Portal"}},
                    }),
                    encoding="utf-8",
                )
                res_apps = subprocess.run(
                    [tf_bin, f"-chdir={apps_dir}", "console"],
                    input='jsonencode({ suffix = local.effective_project_suffix, app_pid = "${local.project_env_prefix}-app-portal${local.project_suffix_tail}" })\n',
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(res_apps.returncode, 0, res_apps.stderr)
                parsed_apps = json.loads(json.loads(res_apps.stdout.strip().splitlines()[-1]))
                self.assertEqual(parsed_apps["suffix"], expected_uat_suffix)
                self.assertEqual(parsed_apps["app_pid"], f"prj-uat-app-portal-{expected_uat_suffix}")

    def test_pass15_budget_scope_split_network_folder_and_platform_bootstrap(self) -> None:
        fin_vars = (REPO_ROOT / "modules/foundation/finops-governance/variables.tf").read_text(encoding="utf-8")
        fin_main = (REPO_ROOT / "modules/foundation/finops-governance/main.tf").read_text(encoding="utf-8")
        self.assertIn("department_budget_scopes", fin_main)
        self.assertIn('startswith(item, "projects/")', fin_main)
        self.assertIn('startswith(item, "folders/") || startswith(item, "organizations/")', fin_main)
        self.assertIn("projects               = length(local.department_budget_scopes[each.key].ancestors) == 0", fin_main)
        self.assertNotIn("{ cost_center = each.key }", fin_main)
        self.assertIn("department_budget_ancestors must provide folders/, organizations/, or projects/", fin_main)
        self.assertIn("cannot mix projects/ with folders/ or organizations/", fin_vars)

        fh_main = (REPO_ROOT / "modules/foundation/folder-hierarchy/main.tf").read_text(encoding="utf-8")
        fh_outs = (REPO_ROOT / "modules/foundation/folder-hierarchy/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('resource "google_folder" "network"', fh_main)
        self.assertIn('output "network_folder_id"', fh_outs)
        self.assertIn('output "environment_network_folder_ids"', fh_outs)

        boot_main = (REPO_ROOT / "foundation/00-bootstrap/main.tf").read_text(encoding="utf-8")
        self.assertEqual(boot_main.count('cost_center = "platform", environment = "shared"'), 2)

        org_vars = (REPO_ROOT / "foundation/01-org-governance/variables.tf").read_text(encoding="utf-8")
        org_main = (REPO_ROOT / "foundation/01-org-governance/main.tf").read_text(encoding="utf-8")
        org_outs = (REPO_ROOT / "foundation/01-org-governance/outputs.tf").read_text(encoding="utf-8")
        self.assertIn('variable "bootstrap_project_number"', org_vars)
        self.assertIn('output "network_folder_id"', org_outs)
        self.assertIn('output "environment_network_folder_ids"', org_outs)
        self.assertIn("network_folder_id", org_main)
        self.assertIn("var.create_dedicated_secops_project ? compact([", org_main)
        self.assertIn("module.backup_project[0].project_number", org_main)
        self.assertIn("platform = [", org_main)

        net_vars = (REPO_ROOT / "foundation/02-security-network/variables.tf").read_text(encoding="utf-8")
        net_main = (REPO_ROOT / "foundation/02-security-network/main.tf").read_text(encoding="utf-8")
        self.assertIn('variable "network_folder_id"', net_vars)
        self.assertIn('variable "environment_network_folder_ids"', net_vars)
        self.assertIn("lookup(var.environment_network_folder_ids, var.environment", net_main)
        self.assertIn('cost_center = "network"', net_main)
        self.assertIn('"cost_center.network"', net_main)

        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
            with tempfile.TemporaryDirectory() as tmp:
                fin_dir = Path(tmp) / "finops-governance"
                shutil.copytree(REPO_ROOT / "modules/foundation/finops-governance", fin_dir)
                cached = REPO_ROOT / "foundation" / "01-org-governance" / ".terraform" / "providers"
                init_cmd = [tf_bin, f"-chdir={fin_dir}", "init", "-input=false"]
                if cached.is_dir():
                    init_cmd.append(f"-plugin-dir={cached}")
                self.assertEqual(subprocess.run(init_cmd, capture_output=True, text=True, check=False).returncode, 0)

                base_finops = {
                    "audit_project_id": "audit-proj",
                    "billing_account": "000000-000000-000000",
                    "prefix": "ent",
                    "region": "asia-southeast1",
                }
                (fin_dir / "valid.auto.tfvars.json").write_text(
                    json.dumps({
                        **base_finops,
                        "department_budgets": {"data": 100, "security": 50, "platform": 25},
                        "department_budget_ancestors": {
                            "data": ["folders/111", "folders/222"],
                            "security": ["projects/333"],
                        },
                    }),
                    encoding="utf-8",
                )
                ok_res = subprocess.run(
                    [tf_bin, f"-chdir={fin_dir}", "console"],
                    input="jsonencode(local.department_budget_scopes)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(ok_res.returncode, 0, ok_res.stderr)
                scopes = json.loads(json.loads(ok_res.stdout.strip()))
                self.assertEqual(scopes["data"], {"ancestors": ["folders/111", "folders/222"], "projects": []})
                self.assertEqual(scopes["security"], {"ancestors": [], "projects": ["projects/333"]})
                self.assertEqual(scopes["platform"], {"ancestors": [], "projects": []})

                (fin_dir / "valid.auto.tfvars.json").write_text(
                    json.dumps({
                        **base_finops,
                        "department_budgets": {"shared": 100},
                        "department_budget_ancestors": {
                            "shared": ["folders/111", "projects/333"],
                        },
                    }),
                    encoding="utf-8",
                )
                bad_res = subprocess.run(
                    [tf_bin, f"-chdir={fin_dir}", "console"],
                    input="keys(var.department_budget_ancestors)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", bad_res.stderr)
                self.assertIn("department_budget_ancestors", bad_res.stderr)

                (fin_dir / "valid.auto.tfvars.json").write_text(
                    json.dumps({
                        **base_finops,
                        "workload_budgets": {
                            "data-platform": {
                                "amount": 100,
                                "projects": ["projects/333"],
                                "labels": {},
                            },
                        },
                    }),
                    encoding="utf-8",
                )
                wb_ok_res = subprocess.run(
                    [tf_bin, f"-chdir={fin_dir}", "console"],
                    input="keys(var.workload_budgets)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(wb_ok_res.returncode, 0, wb_ok_res.stderr)

                (fin_dir / "valid.auto.tfvars.json").write_text(
                    json.dumps({
                        **base_finops,
                        "workload_budgets": {
                            "data-platform": {
                                "amount": 100,
                                "projects": [],
                                "labels": {"a": "1", "b": "2"},
                            },
                        },
                    }),
                    encoding="utf-8",
                )
                wb_bad_res = subprocess.run(
                    [tf_bin, f"-chdir={fin_dir}", "console"],
                    input="keys(var.workload_budgets)\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", wb_bad_res.stderr)
                self.assertIn("workload_budgets", wb_bad_res.stderr)

    def test_pass16_direct_parent_id_and_org_or_folder_guardrails(self) -> None:
        fh_vars = (REPO_ROOT / "modules/foundation/folder-hierarchy/variables.tf").read_text(encoding="utf-8")
        fh_main = (REPO_ROOT / "modules/foundation/folder-hierarchy/main.tf").read_text(encoding="utf-8")
        fh_outs = (REPO_ROOT / "modules/foundation/folder-hierarchy/outputs.tf").read_text(encoding="utf-8")
        self.assertNotIn('resource "google_folder" "root"', fh_main)
        self.assertNotIn('resource "google_folder" "workloads"', fh_main)
        self.assertNotIn('variable "create_root_folder"', fh_vars)
        self.assertNotIn('variable "workload_folders"', fh_vars)
        self.assertEqual(fh_main.count("parent              = var.parent_id"), 3)
        self.assertIn('output "parent_id"', fh_outs)
        self.assertIn('output "root_folder_id"', fh_outs)

        lg_main = (REPO_ROOT / "modules/foundation/logging-guardrails/main.tf").read_text(encoding="utf-8")
        for res in (
            'resource "google_logging_organization_sink" "audit"',
            'resource "google_logging_folder_sink" "audit"',
            'resource "google_organization_iam_audit_config" "data_access"',
            'resource "google_folder_iam_audit_config" "data_access"',
            'resource "google_scc_v2_organization_notification_config" "high_critical"',
            'resource "google_scc_v2_folder_notification_config" "high_critical"',
            'resource "google_organization_iam_member" "foundation_viewers"',
            'resource "google_folder_iam_member" "foundation_viewers"',
        ):
            self.assertIn(res, lg_main)
        self.assertNotRegex(lg_main, r'parent\s*=\s*var\.folder_id')

        tf_bin = shutil.which("terraform")
        if tf_bin is not None:
            cached = REPO_ROOT / "foundation" / "01-org-governance" / ".terraform" / "providers"
            with tempfile.TemporaryDirectory() as tmp:
                tmp_path = Path(tmp)
                for mod_name in ("folder-hierarchy", "logging-guardrails", "scc-secops"):
                    mod_dir = tmp_path / mod_name
                    shutil.copytree(REPO_ROOT / "modules" / "foundation" / mod_name, mod_dir)
                    init_cmd = [tf_bin, f"-chdir={mod_dir}", "init", "-input=false"]
                    if cached.is_dir():
                        init_cmd.append(f"-plugin-dir={cached}")
                    self.assertEqual(subprocess.run(init_cmd, capture_output=True, text=True, check=False).returncode, 0)

                fh_dir = tmp_path / "folder-hierarchy"
                for parent in ("organizations/123456789012", "folders/987654321012"):
                    (fh_dir / "test.auto.tfvars.json").write_text(json.dumps({"parent_id": parent}), encoding="utf-8")
                    res = subprocess.run(
                        [tf_bin, f"-chdir={fh_dir}", "console"],
                        input="var.parent_id\n",
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(res.returncode, 0, res.stderr)
                    self.assertEqual(res.stdout.strip().strip('"'), parent)

                lg_dir = tmp_path / "logging-guardrails"
                for parent, expect in (
                    (
                        "organizations/123456789012",
                        {"is_org_parent": True, "numeric_org_id": "123456789012", "numeric_folder_id": "", "parent_resource": "organizations/123456789012"},
                    ),
                    (
                        "folders/987654321012",
                        {"is_org_parent": False, "numeric_org_id": "", "numeric_folder_id": "987654321012", "parent_resource": "folders/987654321012"},
                    ),
                ):
                    (lg_dir / "test.auto.tfvars.json").write_text(
                        json.dumps({"folder_id": parent, "audit_project_id": "audit-proj", "prefix": "ent"}),
                        encoding="utf-8",
                    )
                    res = subprocess.run(
                        [tf_bin, f"-chdir={lg_dir}", "console"],
                        input="jsonencode({ is_org_parent = local.is_org_parent, numeric_org_id = local.numeric_org_id, numeric_folder_id = local.numeric_folder_id, parent_resource = local.parent_resource })\n",
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(res.returncode, 0, res.stderr)
                    self.assertEqual(json.loads(json.loads(res.stdout.strip())), expect)

                (lg_dir / "test.auto.tfvars.json").write_text(
                    json.dumps({"folder_id": "projects/123456789012", "audit_project_id": "audit-proj", "prefix": "ent"}),
                    encoding="utf-8",
                )
                bad_lg = subprocess.run(
                    [tf_bin, f"-chdir={lg_dir}", "console"],
                    input="var.folder_id\n",
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertIn("Invalid value for variable", bad_lg.stderr)

                scc_dir = tmp_path / "scc-secops"
                for parent, scc_scope, expect in (
                    (
                        "organizations/123456789012",
                        "FOLDER",
                        {"parent_is_org": True, "is_org_scope": True, "is_folder_scope": False, "effective_org_id_num": "123456789012", "parent_target_resource": "organizations/123456789012", "mute_envs": ["dev", "uat"]},
                    ),
                    (
                        "folders/987654321012",
                        "FOLDER",
                        {"parent_is_org": False, "is_org_scope": False, "is_folder_scope": True, "effective_org_id_num": "", "parent_target_resource": "folders/987654321012", "mute_envs": ["dev", "uat"]},
                    ),
                ):
                    (scc_dir / "test.auto.tfvars.json").write_text(
                        json.dumps({
                            "folder_id": parent,
                            "audit_project_id": "audit-proj",
                            "prefix": "ent",
                            "scc_tier": "STANDARD",
                            "scc_scope": scc_scope,
                            "environment_folder_ids": {"dev": "folders/11", "uat": "folders/22", "prod": "folders/33"},
                        }),
                        encoding="utf-8",
                    )
                    res = subprocess.run(
                        [tf_bin, f"-chdir={scc_dir}", "console"],
                        input="jsonencode({ parent_is_org = local.parent_is_org, is_org_scope = local.is_org_scope, is_folder_scope = local.is_folder_scope, effective_org_id_num = local.effective_org_id_num, parent_target_resource = local.parent_target_resource, mute_envs = sort(keys(local.nonprod_mute_folders)) })\n",
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(res.returncode, 0, res.stderr)
                    self.assertEqual(json.loads(json.loads(res.stdout.strip())), expect)


if __name__ == "__main__":
    unittest.main()
