# AGENTS.md

This repository holds Terraform modules and runnable stages for Google Cloud foundations and Medallion platforms.

## Repository Layout

- `modules/foundation/`: Reusable five-file foundation modules (`folder-hierarchy`, `project-factory`, `logging-guardrails`, `finops-governance`, `backup-dr`, `network-security`, `github-wif`, `monitoring-alerts`, `scc-secops`).
- `modules/data/`: Reusable five-file data modules (`governance-catalog`, `bigquery-dataset`, `bigquery-reservations`, `dataplex-scans`, `dataform-repository`, `ml-governance`).
- `modules/app/`: Reusable five-file application factory module (`workload-factory`).
- `foundation/`: Stages `00-bootstrap`, `01-org-governance`, and `02-security-network`.
- `data/sandbox/`: Single-project Medallion deployment root.
- `data/enterprise/`: Multi-project stages `01-platform`, `02-governance-ops`, and optional `03-data-science`.
- `apps/enterprise/`: Per-environment application workload factory stage (see `apps/README.md`).
- `scripts/link-stages.sh`: Links Terraform outputs locally or via GCS into `00_linked.auto.tfvars.json`.
- `CODEOWNERS`: Enforces `@choo737` pull request review ownership across foundation, data, module, and workflow paths.
- `docs/05-enterprise-operationalization-guide.md`: Step-by-step Day-0 through Day-2 operationalization guide.

## Interactive Customer Setup Protocol

Load `.agents/skills/setup-customer-foundation/SKILL.md` and `QUESTIONNAIRE.md` when deploying this repository.
When routed from `https://github.com/choo737/gcp-launchpad`, check optional `platform-context.json` before asking repeated questions.

1. **Create a private repo first**: Never use public forks; run `gh repo create --private` and verify `isPrivate == true`.
2. **Ask the customer first**: Walk through `QUESTIONNAIRE.md` and never guess org IDs, billing accounts, project IDs, or IAM principals.
3. **Confirm path and lifecycle**: Confirm Path 0..3 and active environments (`dev`, `uat`, `prod`).
4. **Propose company acronym and auto suffix**: Ask the organization name or read GCP Organization `displayName`. Strip legal words (`Bhd`, `Berhad`, `Sdn`, `Pte`, `Ltd`, `Inc`, `Corp`). Drop `Holdings` or `Group` only when three core words remain. Propose a 3-6 char lowercase acronym (`prefix`, such as `egr` or `sfg`). Confirm with the user and set `auto_unique_suffix = true` with `project_suffix = ""`. Project IDs follow `prj-<env>-<workload>-<hash4>` (`coe`, `dev`, `uat`, `prod`).
5. **Apply deterministic stage mapping**: Map `QUESTIONNAIRE.md` answers to stage variables for 7-team RBAC, `prj-coe-secops`, `department_budgets`, and `apps/enterprise`.
6. **Verify GCP auth**: Check `gcloud config get-value account` and support `GOOGLE_OAUTH_ACCESS_TOKEN` for named configs.
7. **Store inputs and secrets safely**: Write inputs to `custom.auto.tfvars` or `envs/<env>.tfvars`. Store Dataform PATs in Secret Manager.
8. **Link and verify**: Chain stages with `scripts/link-stages.sh`, seed test rows, verify masking, Knowledge Catalog, and Dataform `SUCCEEDED`.

## Hard Contracts

1. Every directory under `modules/*/*` must contain only `README.md`, `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf`.
2. Runnable stages under `foundation/`, `data/sandbox/`, `data/enterprise/`, and `apps/` contain 7 root files plus `envs/`. Root files are `README.md`, `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `.terraform.lock.hcl`, and `terraform.tfvars.example`.
3. Environment-scoped stages (`foundation/02-security-network`, `data/enterprise/*`, `apps/enterprise`) also contain `envs/{dev,uat,prod}.tfvars.example`.
4. Every `versions.tf` must pin `required_version = ">= 1.8.0"` and `hashicorp/google` `version = ">= 8.0.0, < 9.0.0"`.
5. Never commit real GCP project IDs, organization IDs, folder IDs, billing IDs, secrets, or personal handles.
6. Never commit `terraform.tfvars`, `custom.auto.tfvars`, `platform-context.json`, `*.tfstate*`, `.terraform/`, or `00_linked.auto.tfvars.json`.
7. Keep project IDs within 30 characters and Dataform variables compatible with `https://github.com/choo737/gcp-data-medallion.git`.
8. Never create `GEMINI.md` or `catalog.yaml`.

## Cross-Repo Documentation Invariant

- Keep `tests/suite_doc_contract.py` byte-identical across all five `choo737/gcp-*` repositories.
- Run `gcp-launchpad/scripts/audit-suite-uniformity.py` across sibling repos before pushing shared doc or `Makefile` edits.

## Verification Commands

```bash
make fmt-check
make validate
make test
```

## Available Repository Skills

- `.agents/skills/setup-customer-foundation/SKILL.md`
- `.agents/skills/choose-entry-point/SKILL.md`
- `.agents/skills/add-data-domain/SKILL.md`
- `.agents/skills/add-workload-pillar/SKILL.md`
- `.agents/skills/drift-safe-apply/SKILL.md`
