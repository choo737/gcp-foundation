# GEMINI.md

Follow [AGENTS.md](AGENTS.md) and [.agents/skills/setup-customer-foundation/SKILL.md](.agents/skills/setup-customer-foundation/SKILL.md) for onboarding, contracts, and validation.

## Quick Rules

- Ensure customer work happens in a private repository (`gh repo create --private`) before configuring variables.
- Ask the customer for adoption path, required IDs, `project_suffix`, budget settings, and teardown mode before planning.
- Save customer variables into gitignored `custom.auto.tfvars` and verify active `gcloud` credentials first.
- Keep `modules/foundation/` and `modules/data/` at 5 files per module.
- Keep `foundation/`, `data/sandbox/`, and `data/enterprise/` at 6 files per runnable root.
- Pin `required_version = ">= 1.8.0"` and `hashicorp/google` `>= 8.0.0, < 9.0.0`.
- Chain upstream stage outputs with `scripts/link-stages.sh` into `00_linked.auto.tfvars.json`.
- Validate every edit with `make fmt-check`, `make validate`, and `make test`.
