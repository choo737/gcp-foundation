# CLAUDE.md

Read [AGENTS.md](AGENTS.md), [QUESTIONNAIRE.md](QUESTIONNAIRE.md), [CODEOWNERS](CODEOWNERS), [docs/05-enterprise-operationalization-guide.md](docs/05-enterprise-operationalization-guide.md), and [.agents/skills/setup-customer-foundation/SKILL.md](.agents/skills/setup-customer-foundation/SKILL.md) before running Terraform.

## Quick Rules

- Create a private customer repository (`gh repo create --private`) before storing customer configuration.
- Import optional gitignored `platform-context.json` from `https://github.com/choo737/gcp-launchpad` when present.
- Walk through `QUESTIONNAIRE.md` for adoption path, compliance profile, GCP IDs, environments (`dev`, `uat`, `staging`, `prod`), and deterministic 7-team variable mapping.
- Ask the organization name and strip legal words (`Bhd`, `Berhad`, `Sdn`, `Pte`, `Ltd`, `Inc`, `Corp`).
- Drop `Holdings` or `Group` only when three core words remain.
- Propose a 3-6 char lowercase `prefix` acronym and enable `auto_unique_suffix = true`.
- Write customer variables to gitignored `custom.auto.tfvars` or `envs/<env>.tfvars`, never to tracked files.
- Obey 5-file symmetry in `modules/foundation/`, `modules/data/`, and `modules/app/`.
- Obey root file symmetry, committed `.terraform.lock.hcl`, and `envs/{dev,uat,staging,prod}.tfvars.example` in `foundation/`, `data/sandbox/`, `data/enterprise/`, and `apps/enterprise/`.
- Pass outputs between stages using `scripts/link-stages.sh` (`00_linked.auto.tfvars.json`) locally or via GCS without sharing remote state.
- Keep `hashicorp/google` pinned to `>= 8.0.0, < 9.0.0` and Terraform to `>= 1.8.0`.
- Always run `make fmt-check`, `make validate`, and `make test` after changes.
