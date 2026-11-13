"""Verify Terraform module and runnable root file symmetry contracts."""

from pathlib import Path
import re
import unittest

REPO_ROOT = Path(__file__).resolve().parent.parent

MODULE_FILES = frozenset({
    "README.md",
    "main.tf",
    "variables.tf",
    "outputs.tf",
    "versions.tf",
})

ROOT_FILES = frozenset({
    "README.md",
    "main.tf",
    "variables.tf",
    "outputs.tf",
    "versions.tf",
    "terraform.tfvars.example",
    ".terraform.lock.hcl",
})

MULTI_ENV_ROOTS = frozenset({
    "foundation/02-security-network",
    "data/enterprise/01-platform",
    "data/enterprise/02-governance-ops",
})

EXPECTED_ENV_FILES = frozenset({
    "dev.tfvars.example",
    "staging.tfvars.example",
    "prod.tfvars.example",
})

POST_BOOTSTRAP_ROOTS = frozenset({
    "foundation/01-org-governance",
    "foundation/02-security-network",
    "data/sandbox",
    "data/enterprise/01-platform",
    "data/enterprise/02-governance-ops",
})

EXPECTED_MODULES = frozenset({
    "modules/foundation/folder-hierarchy",
    "modules/foundation/project-factory",
    "modules/foundation/logging-guardrails",
    "modules/foundation/finops-governance",
    "modules/foundation/network-security",
    "modules/foundation/github-wif",
    "modules/foundation/monitoring-alerts",
    "modules/foundation/scc-secops",
    "modules/data/governance-catalog",
    "modules/data/bigquery-dataset",
    "modules/data/bigquery-reservations",
    "modules/data/dataplex-scans",
    "modules/data/dataform-repository",
})

EXPECTED_ROOTS = frozenset({
    "foundation/00-bootstrap",
    "foundation/01-org-governance",
    "foundation/02-security-network",
    "data/sandbox",
    "data/enterprise/01-platform",
    "data/enterprise/02-governance-ops",
})

IGNORED_NAMES = frozenset({
    ".terraform",
    "__pycache__",
    ".DS_Store",
    "terraform.tfstate",
    "terraform.tfstate.backup",
    "terraform.tfvars",
})


def _is_ignored(name: str) -> bool:
    if name in IGNORED_NAMES:
        return True
    if name.endswith((".auto.tfvars", ".auto.tfvars.json", ".tfplan")):
        return True
    if name.startswith("terraform.tfstate."):
        return True
    return False


def _visible_entries(directory: Path) -> set[str]:
    return {
        entry.name
        for entry in directory.iterdir()
        if not _is_ignored(entry.name)
    }


def _discover_modules() -> list[Path]:
    modules_dir = REPO_ROOT / "modules"
    if not modules_dir.is_dir():
        return []
    found: list[Path] = []
    for domain_dir in sorted(modules_dir.iterdir()):
        if not domain_dir.is_dir() or domain_dir.name.startswith("."):
            continue
        for mod_dir in sorted(domain_dir.iterdir()):
            if mod_dir.is_dir() and not mod_dir.name.startswith("."):
                found.append(mod_dir)
    return found


def _discover_runnable_roots() -> list[Path]:
    roots: list[Path] = []
    foundation_dir = REPO_ROOT / "foundation"
    if foundation_dir.is_dir():
        for stage_dir in sorted(foundation_dir.iterdir()):
            if stage_dir.is_dir() and not stage_dir.name.startswith("."):
                roots.append(stage_dir)

    sandbox_dir = REPO_ROOT / "data" / "sandbox"
    if sandbox_dir.is_dir():
        roots.append(sandbox_dir)

    enterprise_dir = REPO_ROOT / "data" / "enterprise"
    if enterprise_dir.is_dir():
        for stage_dir in sorted(enterprise_dir.iterdir()):
            if stage_dir.is_dir() and not stage_dir.name.startswith("."):
                roots.append(stage_dir)

    return roots


class RepoSymmetryTest(unittest.TestCase):
    """Validate 13 five-file modules, 6 runnable roots, lockfiles, and version pins."""

    def test_modules_obey_five_file_contract(self) -> None:
        modules = _discover_modules()
        discovered_rel = {str(m.relative_to(REPO_ROOT)) for m in modules}
        self.assertEqual(discovered_rel, EXPECTED_MODULES)

        for mod_dir in modules:
            with self.subTest(module=str(mod_dir.relative_to(REPO_ROOT))):
                actual = _visible_entries(mod_dir)
                self.assertEqual(
                    actual,
                    MODULE_FILES,
                    f"{mod_dir} must contain exact 5-file contract: {sorted(MODULE_FILES)}",
                )
                for entry in mod_dir.iterdir():
                    if entry.name in MODULE_FILES:
                        self.assertTrue(
                            entry.is_file(),
                            f"Expected file, found non-file: {entry}",
                        )

    def test_runnable_roots_obey_root_and_env_contract(self) -> None:
        roots = _discover_runnable_roots()
        discovered_rel = {str(r.relative_to(REPO_ROOT)) for r in roots}
        self.assertEqual(discovered_rel, EXPECTED_ROOTS)

        for root_dir in roots:
            rel = str(root_dir.relative_to(REPO_ROOT))
            expected_entries = set(ROOT_FILES)
            if rel in MULTI_ENV_ROOTS:
                expected_entries.add("envs")

            with self.subTest(root=rel):
                actual = _visible_entries(root_dir)
                self.assertEqual(
                    actual,
                    expected_entries,
                    f"{root_dir} must contain exact contract: {sorted(expected_entries)}",
                )
                for fname in ROOT_FILES:
                    fpath = root_dir / fname
                    self.assertTrue(
                        fpath.is_file(),
                        f"Expected file, found non-file: {fpath}",
                    )
                if rel in MULTI_ENV_ROOTS:
                    envs_dir = root_dir / "envs"
                    self.assertTrue(envs_dir.is_dir())
                    self.assertEqual(_visible_entries(envs_dir), EXPECTED_ENV_FILES)

    def test_versions_tf_pins_terraform_and_google_provider(self) -> None:
        targets = _discover_modules() + _discover_runnable_roots()
        self.assertEqual(len(targets), len(EXPECTED_MODULES) + len(EXPECTED_ROOTS))
        tf_pattern = re.compile(r'required_version\s*=\s*">=\s*1\.8\.0"')
        google_pattern = re.compile(
            r'source\s*=\s*"hashicorp/google"[\s\S]*?version\s*=\s*">=\s*8\.0\.0,\s*<\s*9\.0\.0"'
        )
        for target in targets:
            versions_path = target / "versions.tf"
            rel = str(target.relative_to(REPO_ROOT))
            with self.subTest(versions=str(versions_path.relative_to(REPO_ROOT))):
                text = versions_path.read_text(encoding="utf-8")
                self.assertRegex(text, tf_pattern)
                self.assertRegex(text, google_pattern)
                if rel in POST_BOOTSTRAP_ROOTS:
                    self.assertIn('backend "gcs" {}', text)
                elif rel == "foundation/00-bootstrap":
                    self.assertNotIn('backend "gcs"', text)


if __name__ == "__main__":
    unittest.main()
