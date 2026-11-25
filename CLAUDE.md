# CLAUDE.md

Read [AGENTS.md](AGENTS.md), [QUESTIONNAIRE.md](QUESTIONNAIRE.md), [CODEOWNERS](CODEOWNERS), and [.agents/skills/setup-customer-foundation/SKILL.md](.agents/skills/setup-customer-foundation/SKILL.md) before running Terraform.
Also read [docs/05-enterprise-operationalization-guide.md](docs/05-enterprise-operationalization-guide.md) for Day-0 through Day-2 rollout steps.

## Quick Rules

- Create a private customer repository (`gh repo create --private`) before storing customer configuration.
- Import optional gitignored `platform-context.json` from `https://github.com/choo737/gcp-launchpad` when present.
- Walk through `QUESTIONNAIRE.md` for adoption path, compliance profile, GCP IDs, and environments (`dev`, `uat`, `prod`).
- Map deterministic 7-team variables for `foundation_iam_groups`, `prj-coe-secops`, `department_budgets`, and `apps/enterprise`.
- Ask the organization name and strip legal words (`Bhd`, `Berhad`, `Sdn`, `Pte`, `Ltd`, `Inc`, `Corp`).
- Drop `Holdings` or `Group` only when three core words remain.
- Propose a 3-6 char lowercase `prefix` acronym and enable `auto_unique_suffix = true`.
- Keep project IDs in `prj-<env>-<workload>-<hash4>` format (`<= 30` chars, `1-4` char override).
- Write customer variables to gitignored `custom.auto.tfvars` or `envs/<env>.tfvars`, never to tracked files.
- Obey 5-file symmetry in `modules/foundation/`, `modules/data/`, and `modules/app/`.
- Obey 7-file root symmetry in `foundation/`, `data/sandbox/`, `data/enterprise/`, and `apps/enterprise/`.
- Include `envs/{dev,uat,prod}.tfvars.example` in all environment-scoped stages.
- Pass outputs between stages using `scripts/link-stages.sh` (`00_linked.auto.tfvars.json`) locally or via GCS.
- Keep `hashicorp/google` pinned to `>= 8.0.0, < 9.0.0` and Terraform to `>= 1.8.0`.
- Never create `GEMINI.md` or `catalog.yaml`, and keep `tests/suite_doc_contract.py` synced across the suite.
- Always run `make fmt-check`, `make validate`, and `make test` after changes.
