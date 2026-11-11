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


if __name__ == "__main__":
    unittest.main()
