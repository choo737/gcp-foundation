# GCP Foundation

This repository deploys a modular Google Cloud landing zone and Medallion data platform using Terraform.

## 3-Repository Suite Map

| Repository | Owner | Lifecycle | Responsibility |
| --- | --- | --- | --- |
| `gcp-foundation` | Day 1 Platform Team (Alice) | Day 0-1 | Bootstrap WIF, folders, 36 Org Policies, KMS, VPC, BigQuery datasets, governance tags, Dataform |
| `gcp-data-ingestion` | Day 10 Ingestion Team (Bob) | Day 10+ | Pub/Sub, Dataflow, Datastream, and GCS batch pipelines feeding Bronze tables |
| `gcp-data-medallion` | Analytics Engineering Team | Continuous | Dataform SQLX transformations across Bronze, Silver, and Gold layers |

## Create Your Private Repository (Do Not Fork Publicly)

- GitHub forces normal forks of public repos to stay public.
- Pull requests in forks also default back to the public upstream.
- Instead, click **Use this template** on GitHub or run:

```bash
gh repo create acme-corp/gcp-foundation --private --template choo737/gcp-foundation --clone
```

## Choose Your Entry Point

| Path | Target Scope | Stage Sequence |
| --- | --- | --- |
| Path 0: Bootstrap (Optional) | Existing seed project | `foundation/00-bootstrap` |
| Path 1: Greenfield | Org or top folder | `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` |
| Path 2: Brownfield | Existing `data-platform` folder | `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` |
| Path 3: Sandbox | One existing GCP project | `data/sandbox` |

## Interactive Customer Onboarding

If you use a coding agent, it follows [.agents/skills/setup-customer-foundation/SKILL.md](.agents/skills/setup-customer-foundation/SKILL.md):

1. Create a private repository first (`gh repo create <owner>/<repo> --private --template choo737/gcp-foundation --clone`).
2. Ask for your adoption path, GCP IDs, `prefix`, `project_suffix`, budget target, and lifecycle flags.
3. Verify active `gcloud` authentication (`gcloud config get-value account` or `GOOGLE_OAUTH_ACCESS_TOKEN`).
4. Write customer values into gitignored `custom.auto.tfvars` and link stages via `scripts/link-stages.sh` (`00_linked.auto.tfvars.json`).
5. Use `--export-gcs` and `--from-gcs` for cross-repo CI/CD handoffs without sharing `.tfstate` files.
6. Leave `git_token_secret_version` empty for standalone Dataform, or store a PAT in Secret Manager.
7. Seed test rows and run post-deploy checks on FinOps, masking, Dataplex scans, and Dataform runs.

## Repository Structure

- `modules/foundation/`: Folder hierarchy, project factory, logging guardrails, FinOps governance, network security, and `github-wif`.
- `modules/data/`: Governance catalog, BigQuery datasets, slot reservations, Dataplex scans, and Dataform repositories.
- `foundation/`: Stages `00-bootstrap`, `01-org-governance`, and `02-security-network`.
- `data/sandbox/`: Single-project Medallion stack for fast validation.
- `data/enterprise/`: Two-stage multi-project data platform (`01-platform` and `02-governance-ops`).
- `scripts/link-stages.sh`: Links Terraform outputs locally or via GCS into `00_linked.auto.tfvars.json`.
- `docs/`: Architecture, entry points, and Cloudera-to-BigQuery migration notes.

## Security & Governance Baseline

- Stage 00 configures hardened `tfstate` and `iac-outputs` buckets plus keyless GitHub Actions WIF.
- Stage 01 configures Log Analytics, optional SIEM/SCC notifications, and a 36-policy Org Policy baseline.
- Stage 02 configures CMEK, VPC Flow Logs, DNS query logging, and default deny-all egress policies.

## Quick Verification

```bash
make fmt-check
make validate
make test
```

## Documentation Index

- [Architecture Overview](docs/01-architecture.md)
- [Entry Points Guide](docs/02-entry-points.md)
- [Cloudera to BigQuery Mapping](docs/03-cloudera-to-bigquery.md)
