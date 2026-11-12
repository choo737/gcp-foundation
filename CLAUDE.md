# CLAUDE.md

Read [AGENTS.md](AGENTS.md) and [.agents/skills/setup-customer-foundation/SKILL.md](.agents/skills/setup-customer-foundation/SKILL.md) before running any Terraform commands.

## Quick Rules

- Create a private customer repository (`gh repo create --private`) before storing customer configuration.
- Ask the customer for their adoption path, GCP IDs, `project_suffix`, and environment (`dev`, `staging`, `prod`) first.
- Write customer variables to gitignored `custom.auto.tfvars` or `envs/<env>.tfvars`, never to tracked files.
- Obey 5-file symmetry in `modules/foundation/` and `modules/data/`.
- Obey root file symmetry, committed `.terraform.lock.hcl`, and `envs/{dev,staging,prod}.tfvars.example` in `foundation/`, `data/sandbox/`, and `data/enterprise/`.
- Pass outputs between stages using `scripts/link-stages.sh` (`00_linked.auto.tfvars.json`) locally or via GCS without sharing remote state.
- Keep `hashicorp/google` pinned to `>= 8.0.0, < 9.0.0` and Terraform to `>= 1.8.0`.
- Always run `make fmt-check`, `make validate`, and `make test` after changes.
