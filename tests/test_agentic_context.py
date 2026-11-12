"""Verify agent instructions, skills, CI workflow, and stage linker."""

import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_SKILLS = (
    "setup-customer-foundation",
    "choose-entry-point",
    "add-data-domain",
    "add-workload-pillar",
    "drift-safe-apply",
)

EXPECTED_ROOTS = (
    "foundation/00-bootstrap",
    "foundation/01-org-governance",
    "foundation/02-security-network",
    "data/sandbox",
    "data/enterprise/01-platform",
    "data/enterprise/02-governance-ops",
)


class AgenticContextAndToolingTest(unittest.TestCase):
    """Validate agent docs, skills, CI/Makefile parity, and link-stages.sh."""

    def test_agent_instructions_exist_and_align(self) -> None:
        required_refs = (
            "modules/foundation/",
            "modules/data/",
            "foundation/",
            "data/sandbox/",
            "data/enterprise/",
            "scripts/link-stages.sh",
            "00_linked.auto.tfvars.json",
            "setup-customer-foundation",
            "custom.auto.tfvars",
            "--private",
            "8.0.0",
            "1.8.0",
        )
        for doc_name in ("AGENTS.md", "CLAUDE.md", "GEMINI.md"):
            doc_path = REPO_ROOT / doc_name
            with self.subTest(doc=doc_name):
                self.assertTrue(doc_path.is_file(), f"Missing {doc_name}")
                content = doc_path.read_text(encoding="utf-8")
                for ref in required_refs:
                    self.assertIn(ref, content, f"{doc_name} missing ref {ref}")

    def test_project_id_length_math_within_30_chars(self) -> None:
        max_prefix = 8
        max_suffix = 8
        project_prefix_len = max_prefix + 1 + max_suffix
        suffixes = (
            "-audit",
            "-network",
            "-data-gov",
            "-data-core",
            "-data-123456",
            "-data-etl",
            "-data-bi",
        )
        for suffix in suffixes:
            with self.subTest(suffix=suffix):
                self.assertLessEqual(project_prefix_len + len(suffix), 30)

    def test_no_stale_abbreviated_project_suffixes(self) -> None:
        stale_tokens = (
            "fnd-" + "audit",
            "fnd_" + "audit",
            "fnd-" + "netsec",
            "fnd_" + "netsec",
            "dp-" + "gov",
            "dp_" + "gov",
            "dp-" + "st-",
            "dp_" + "st_",
            "dp-" + "cp-",
            "dp_" + "cp_",
        )
        skip_dirs = {".git", ".terraform", "__pycache__", ".pytest_cache"}
        for path in sorted(REPO_ROOT.rglob("*")):
            if not path.is_file() or any(part in skip_dirs for part in path.parts):
                continue
            text = path.read_text(encoding="utf-8", errors="ignore").lower()
            rel = str(path.relative_to(REPO_ROOT))
            with self.subTest(file=rel):
                for tok in stale_tokens:
                    self.assertNotIn(tok, text, f"Stale suffix '{tok}' in {rel}")

    def test_dataform_git_remote_requires_token_secret(self) -> None:
        df_main = (
            REPO_ROOT / "modules" / "data" / "dataform-repository" / "main.tf"
        ).read_text(encoding="utf-8")
        df_out = (
            REPO_ROOT / "modules" / "data" / "dataform-repository" / "outputs.tf"
        ).read_text(encoding="utf-8")

        self.assertRegex(
            df_main,
            r'enable_git_remote\s*=\s*var\.git_remote_url\s*!=\s*""\s*&&\s*var\.git_token_secret_version\s*!=\s*""',
        )
        block_kw = "dyn" + "amic"
        self.assertRegex(
            df_main,
            rf'{block_kw}\s+"git_remote_settings"\s*\{{\s*for_each\s*=\s*local\.enable_git_remote\s*\?\s*\[1\]\s*:\s*\[\]',
        )
        self.assertIn(
            "authentication_token_secret_version = var.git_token_secret_version",
            df_main,
        )
        self.assertNotIn(
            'authentication_token_secret_version = var.git_token_secret_version != "" ? var.git_token_secret_version : null',
            df_main,
        )
        self.assertIn("count = local.enable_git_remote ? 1 : 0", df_main)
        self.assertIn(
            "count = var.enable_scheduled_workflow && local.enable_git_remote ? 1 : 0",
            df_main,
        )
        self.assertIn(
            'try(google_dataform_repository_release_config.prod[0].name, "")',
            df_out,
        )

    def test_dataplex_scans_wait_for_masked_reader_propagation(self) -> None:
        for rel in (
            "data/sandbox/main.tf",
            "data/enterprise/02-governance-ops/main.tf",
        ):
            text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            with self.subTest(file=rel):
                self.assertIn('resource "time_sleep" "dataplex_iam_propagation"', text)
                self.assertIn("var.dataplex_iam_propagation_seconds", text)
                self.assertIn("time_sleep.dataplex_iam_propagation", text)
                self.assertIn('resource "time_sleep" "service_identity_propagation"', text)
                self.assertIn("encryption_configuration", text)

    def test_no_empty_string_coalesce_in_terraform(self) -> None:
        bad_coalesce = re.compile(r'coalesce\([^)]*""')
        skip_dirs = {".git", ".terraform", "__pycache__", ".pytest_cache"}
        for tf_path in sorted(REPO_ROOT.rglob("*.tf")):
            if any(part in skip_dirs for part in tf_path.parts):
                continue
            text = tf_path.read_text(encoding="utf-8")
            rel = str(tf_path.relative_to(REPO_ROOT))
            with self.subTest(file=rel):
                self.assertIsNone(
                    bad_coalesce.search(text),
                    f"Empty-string coalesce found in {rel}",
                )

        platform_main = (
            REPO_ROOT / "data" / "enterprise" / "01-platform" / "main.tf"
        ).read_text(encoding="utf-8")
        self.assertIn('resource "time_sleep" "service_agent_propagation"', platform_main)

    def test_skills_have_valid_frontmatter(self) -> None:
        fm_re = re.compile(
            r"\A---\nname:\s*([a-z0-9-]+)\ndescription:\s*(.+)\n---\n",
            re.MULTILINE,
        )
        for skill in REQUIRED_SKILLS:
            skill_path = REPO_ROOT / ".agents" / "skills" / skill / "SKILL.md"
            with self.subTest(skill=skill):
                self.assertTrue(skill_path.is_file(), f"Missing skill {skill_path}")
                text = skill_path.read_text(encoding="utf-8")
                match = fm_re.match(text)
                self.assertIsNotNone(match, f"Invalid frontmatter in {skill_path}")
                self.assertEqual(match.group(1), skill)
                self.assertGreater(len(match.group(2).strip()), 10)

        setup_skill = (
            REPO_ROOT / ".agents" / "skills" / "setup-customer-foundation" / "SKILL.md"
        ).read_text(encoding="utf-8")
        for token in (
            "--private",
            "${PREFIX//-/_}_billing_export",
            "INSERT INTO",
            "compilationErrors",
            "SUCCEEDED",
        ):
            self.assertIn(token, setup_skill)

    def test_makefile_and_ci_cover_all_roots(self) -> None:
        makefile_text = (REPO_ROOT / "Makefile").read_text(encoding="utf-8")
        ci_text = (REPO_ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        for root in EXPECTED_ROOTS:
            self.assertIn(root, makefile_text)
        self.assertIn("00_linked.auto.tfvars.json", makefile_text)
        self.assertIn("1.8.5", ci_text)
        self.assertIn("contents: read", ci_text)
        self.assertRegex(ci_text, r"actions/checkout@[0-9a-f]{40}")
        self.assertRegex(ci_text, r"hashicorp/setup-terraform@[0-9a-f]{40}")
        self.assertRegex(ci_text, r"actions/setup-python@[0-9a-f]{40}")
        self.assertIn("make fmt-check", ci_text)
        self.assertIn("make validate", ci_text)
        self.assertIn("make test", ci_text)

    def test_link_stages_script_syntax_and_merging(self) -> None:
        script_path = REPO_ROOT / "scripts" / "link-stages.sh"
        self.assertTrue(script_path.is_file())
        mode = script_path.stat().st_mode
        self.assertTrue(mode & stat.S_IXUSR, "scripts/link-stages.sh must be executable")

        syntax_res = subprocess.run(
            ["bash", "-n", str(script_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(syntax_res.returncode, 0, syntax_res.stderr)

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            bin_dir.mkdir()
            src_a = tmp_path / "stage_a"
            src_b = tmp_path / "stage_b"
            dst = tmp_path / "stage_dst"
            src_a.mkdir()
            src_b.mkdir()
            dst.mkdir()

            (dst / "variables.tf").write_text(
                'variable "folder_id" {\n  type = string\n}\n'
                'variable "kms_key_id" {\n  type = string\n}\n'
                'variable "secret_val" {\n  type = string\n}\n'
                'variable "stale_var" {\n  type = string\n}\n',
                encoding="utf-8",
            )
            out_path = dst / "00_linked.auto.tfvars.json"
            out_path.write_text('{"stale_var": "old"}\n', encoding="utf-8")

            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json, sys\n"
                "arg = next(a for a in sys.argv[1:] if a.startswith('-chdir='))\n"
                "src = arg.split('=', 1)[1]\n"
                "if src.endswith('stage_a'):\n"
                "    print(json.dumps({'folder_id': {'value': 'folders/111'}, 'secret_val': {'value': 'top', 'sensitive': True}, 'unused': {'value': 'x'}}))\n"
                "else:\n"
                "    print(json.dumps({'kms_key_id': {'value': 'projects/p/locations/r/keyRings/k/cryptoKeys/c'}}))\n",
                encoding="utf-8",
            )
            tf_shim.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"

            run_res = subprocess.run(
                [str(script_path), str(src_a), str(src_b), str(dst)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(run_res.returncode, 0, run_res.stderr)

            linked = json.loads(out_path.read_text(encoding="utf-8"))
            self.assertEqual(
                linked,
                {
                    "folder_id": "folders/111",
                    "kms_key_id": "projects/p/locations/r/keyRings/k/cryptoKeys/c",
                },
            )
            self.assertEqual(stat.S_IMODE(out_path.stat().st_mode), 0o600)

    def test_enterprise_org_policy_baseline_coverage(self) -> None:
        boolean_constraints = (
            "iam.disableServiceAccountKeyCreation",
            "iam.disableServiceAccountKeyUpload",
            "iam.automaticIamGrantsForDefaultServiceAccounts",
            "iam.disableAuditLoggingExemption",
            "iam.restrictCrossProjectServiceAccountLienRemoval",
            "storage.uniformBucketLevelAccess",
            "storage.publicAccessPrevention",
            "storage.secureHttpTransport",
            "sql.restrictPublicIp",
            "sql.restrictAuthorizedNetworks",
            "bigquery.disableBQOmniAWS",
            "bigquery.disableBQOmniAzure",
            "ainotebooks.restrictPublicIp",
            "compute.requireShieldedVm",
            "compute.skipDefaultNetworkCreation",
            "compute.requireOsLogin",
            "compute.disableSerialPortAccess",
            "compute.disableGuestAttributesAccess",
            "compute.disableNestedVirtualization",
            "compute.disableVpcExternalIpv6",
            "compute.disableInternetNetworkEndpointGroup",
            "compute.setNewProjectDefaultToZonalDNSOnly",
            "compute.restrictXpnProjectLienRemoval",
            "cloudbuild.disableCreateDefaultServiceAccount",
            "run.managed.requireInvokerIam",
            "container.managed.enablePrivateNodes",
        )
        deny_all_constraints = (
            "compute.vmExternalIpAccess",
            "compute.vmCanIpForward",
            "iam.allowServiceAccountCredentialLifetimeExtension",
        )
        list_value_constraints = (
            "gcp.resourceLocations",
            "iam.allowedPolicyMemberDomains",
            "essentialcontacts.allowedContactDomains",
            "storage.restrictAuthTypes",
            "run.allowedIngress",
            "cloudfunctions.allowedIngressSettings",
            "compute.restrictProtocolForwardingCreationForTypes",
        )
        self.assertEqual(
            len(boolean_constraints) + len(deny_all_constraints) + len(list_value_constraints),
            36,
        )

        mod_dir = REPO_ROOT / "modules" / "foundation" / "logging-guardrails"
        mod_vars = (mod_dir / "variables.tf").read_text(encoding="utf-8")
        mod_main = (mod_dir / "main.tf").read_text(encoding="utf-8")
        mod_outs = (mod_dir / "outputs.tf").read_text(encoding="utf-8")

        for constraint in boolean_constraints + deny_all_constraints:
            with self.subTest(constraint=constraint):
                self.assertIn(f'"{constraint}"', mod_vars)

        for constraint in list_value_constraints:
            with self.subTest(constraint=constraint):
                self.assertIn(f"/policies/{constraint}", mod_main)

        self.assertIn("normalized_policy_member_domains", mod_main)
        self.assertIn("normalized_contact_domains", mod_main)
        self.assertIn('output "enforced_org_policy_names"', mod_outs)
        self.assertIn("enable_analytics = var.enable_log_analytics", mod_main)
        self.assertIn('resource "google_logging_linked_dataset" "audit"', mod_main)
        self.assertIn('resource "google_pubsub_topic" "siem_logs"', mod_main)
        self.assertIn('resource "google_scc_v2_folder_notification_config" "high_critical"', mod_main)
        self.assertIn('resource "google_essential_contacts_contact" "this"', mod_main)
        self.assertIn("roles/logging.privateLogViewer", mod_main)
        self.assertIn("roles/iam.securityReviewer", mod_main)
        self.assertIn("roles/compute.networkViewer", mod_main)

        stage_dir = REPO_ROOT / "foundation" / "01-org-governance"
        stage_vars = (stage_dir / "variables.tf").read_text(encoding="utf-8")
        stage_main = (stage_dir / "main.tf").read_text(encoding="utf-8")
        stage_outs = (stage_dir / "outputs.tf").read_text(encoding="utf-8")

        list_vars = (
            "allowed_policy_member_domains",
            "allowed_contact_domains",
            "denied_storage_auth_types",
            "allowed_cloud_run_ingress",
            "allowed_cloud_functions_ingress",
            "allowed_protocol_forwarding_types",
        )
        for var_name in list_vars:
            with self.subTest(variable=var_name):
                self.assertIn(f'variable "{var_name}"', mod_vars)
                self.assertIn(f'variable "{var_name}"', stage_vars)
                self.assertRegex(stage_main, rf"{var_name}\s*=\s*var\.{var_name}")

        self.assertIn('"essentialcontacts.googleapis.com"', stage_main)
        self.assertRegex(stage_main, r"allowed_resource_locations\s*=\s*\[\"in:\$\{var\.region\}-locations\"\]")
        self.assertIn('output "enforced_org_policy_names"', stage_outs)

    def test_link_stages_gcs_export_and_from_gcs(self) -> None:
        script_path = REPO_ROOT / "scripts" / "link-stages.sh"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bin_dir = tmp_path / "bin"
            gcs_store = tmp_path / "gcs_store"
            src = tmp_path / "stage_src"
            dst = tmp_path / "stage_dst"
            bin_dir.mkdir()
            gcs_store.mkdir()
            src.mkdir()
            dst.mkdir()

            (dst / "variables.tf").write_text(
                'variable "kms_key_id" {\n  type = string\n}\n'
                'variable "vpc_id" {\n  type = string\n}\n'
                'variable "secret_val" {\n  type = string\n}\n',
                encoding="utf-8",
            )

            tf_shim = bin_dir / "terraform"
            tf_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({\n"
                "    'kms_key_id': {'value': 'projects/p/locations/r/keyRings/k/cryptoKeys/c'},\n"
                "    'secret_val': {'value': 'top-secret', 'sensitive': True},\n"
                "    'nullable': {'value': None},\n"
                "    'unused': {'value': 'ignore-me'},\n"
                "}))\n",
                encoding="utf-8",
            )
            tf_shim.chmod(0o755)

            gcloud_shim = bin_dir / "gcloud"
            gcloud_shim.write_text(
                "#!/usr/bin/env python3\n"
                "import os, shutil, stat, sys\n"
                "from pathlib import Path\n"
                "store = Path(os.environ['TEST_GCS_STORE'])\n"
                "args = sys.argv[1:]\n"
                "assert args[:1] == ['storage']\n"
                "if args[1] == 'cp':\n"
                "    src_file = Path(args[2])\n"
                "    assert stat.S_IMODE(src_file.stat().st_mode) == 0o600\n"
                "    rel = args[3].removeprefix('gs://')\n"
                "    target = store / rel\n"
                "    target.parent.mkdir(parents=True, exist_ok=True)\n"
                "    shutil.copyfile(src_file, target)\n"
                "elif args[1] == 'cat':\n"
                "    rel = args[2].removeprefix('gs://')\n"
                "    sys.stdout.write((store / rel).read_text(encoding='utf-8'))\n"
                "else:\n"
                "    raise SystemExit(f'Unexpected gcloud args: {args}')\n",
                encoding="utf-8",
            )
            gcloud_shim.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            env["TEST_GCS_STORE"] = str(gcs_store)

            export_res = subprocess.run(
                [str(script_path), "--export-gcs", "gs://test-iac/01.json", str(src)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(export_res.returncode, 0, export_res.stderr)

            exported_obj = json.loads((gcs_store / "test-iac" / "01.json").read_text(encoding="utf-8"))
            self.assertEqual(
                exported_obj,
                {
                    "kms_key_id": "projects/p/locations/r/keyRings/k/cryptoKeys/c",
                    "unused": "ignore-me",
                },
            )

            extra_obj = gcs_store / "test-iac" / "02.json"
            extra_obj.write_text(json.dumps({"vpc_id": "projects/p/global/networks/n"}), encoding="utf-8")

            from_res = subprocess.run(
                [
                    str(script_path),
                    "--from-gcs",
                    "gs://test-iac/01.json",
                    "gs://test-iac/02.json",
                    str(dst),
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(from_res.returncode, 0, from_res.stderr)

            linked_path = dst / "00_linked.auto.tfvars.json"
            self.assertEqual(
                json.loads(linked_path.read_text(encoding="utf-8")),
                {
                    "kms_key_id": "projects/p/locations/r/keyRings/k/cryptoKeys/c",
                    "vpc_id": "projects/p/global/networks/n",
                },
            )
            self.assertEqual(stat.S_IMODE(linked_path.stat().st_mode), 0o600)

    def test_github_wif_cel_guard_and_bootstrap_hardening(self) -> None:
        wif_dir = REPO_ROOT / "modules" / "foundation" / "github-wif"
        wif_vars = (wif_dir / "variables.tf").read_text(encoding="utf-8")
        wif_main = (wif_dir / "main.tf").read_text(encoding="utf-8")
        self.assertIn("^[A-Za-z0-9-]+$", wif_vars)
        self.assertIn("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", wif_vars)
        self.assertIn('local.attribute_condition != ""', wif_main)
        self.assertIn("assertion.repository_owner", wif_main)

        boot_main = (REPO_ROOT / "foundation" / "00-bootstrap" / "main.tf").read_text(encoding="utf-8")
        self.assertIn("uniform_bucket_level_access = true", boot_main)
        self.assertIn('public_access_prevention    = "enforced"', boot_main)
        self.assertIn("-tfstate", boot_main)
        self.assertIn("-iac-outputs", boot_main)

    def test_network_firewall_policy_and_observability_controls(self) -> None:
        net_main = (REPO_ROOT / "modules" / "foundation" / "network-security" / "main.tf").read_text(
            encoding="utf-8"
        )
        self.assertNotIn('resource "google_compute_firewall" "psc_egress"', net_main)
        self.assertIn('resource "google_compute_network_firewall_policy" "egress"', net_main)
        self.assertIn('resource "google_compute_network_firewall_policy_association" "egress"', net_main)
        self.assertIn("priority        = 1000", net_main)
        self.assertIn("priority        = 65530", net_main)
        self.assertIn('action          = "deny"', net_main)
        self.assertIn('dest_ip_ranges = ["0.0.0.0/0"]', net_main)
        self.assertIn('ip_protocol = "all"', net_main)
        self.assertIn('resource "google_dns_policy" "logging"', net_main)
        self.assertIn('"pkg.dev."', net_main)
        self.assertIn('"gcr.io."', net_main)
        self.assertIn("log_config", net_main)

        stage_outs = (REPO_ROOT / "foundation" / "02-security-network" / "outputs.tf").read_text(
            encoding="utf-8"
        )
        self.assertIn('output "vpc_id"', stage_outs)
        self.assertIn('output "network_id"', stage_outs)
        self.assertIn('output "subnet_id"', stage_outs)

    def test_cdc_bronze_schema_parity_and_sandbox_outputs(self) -> None:
        for rel in ("data/sandbox/main.tf", "data/enterprise/02-governance-ops/main.tf"):
            text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            with self.subTest(file=rel):
                self.assertEqual(text.count('"_metadata_deleted"'), 2)

        sandbox_outs = (REPO_ROOT / "data" / "sandbox" / "outputs.tf").read_text(encoding="utf-8")
        for out_name in ("project_id", "region", "prefix", "bronze_dataset_id", "ops_telemetry_dataset_id"):
            with self.subTest(output=out_name):
                self.assertIn(f'output "{out_name}"', sandbox_outs)


if __name__ == "__main__":
    unittest.main()
