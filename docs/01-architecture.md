# Architecture Overview

This repository separates cloud foundation guardrails from data platform operations across independent Terraform state roots.

## Folder Topology

```text
organizations/<org_id> (or folders/<parent_id>)
└── <prefix>-gcp-foundation
    ├── 01-shared-infrastructure
    │   └── <prefix>-audit
    ├── 02-environments
    │   └── {dev, staging, prod}
    │       ├── <prefix>-<suffix>-network
    │       └── data-platform
    │           ├── storage
    │           │   ├── <prefix>-<suffix>-data-gov
    │           │   ├── <prefix>-<suffix>-data-core
    │           │   └── <prefix>-<suffix>-data-<domain>
    │           └── compute
    │               ├── <prefix>-<suffix>-data-etl
    │               └── <prefix>-<suffix>-data-bi
    └── 02-workloads
        └── data-platform (brownfield fallback)
```

## Five-Project Data Separation

| Project | Layer | Responsibility |
| --- | --- | --- |
| `data-gov` | Governance | Data Catalog taxonomy, policy tags, `LAST_FOUR_CHARACTERS` masking, Dataplex glossary |
| `data-core` | Storage | Versioned landing bucket (`incoming/` lifecycle), `bronze_raw`, `silver_curated`, `silver_assertions`, `quarantine` |
| `data-<domain>` | Storage | Domain-scoped `gold_mart` datasets such as `fin` |
| `data-etl` | Compute | Artifact Registry, Dataform repository, ETL SA, `ops_telemetry`, BigQuery slot reservations |
| `data-bi` | Compute | Zero-table BI query project isolating analyst compute and billing |

## Cross-Stage & Cross-Repo Handoff: Day 1 Alice to Day 10 Bob

Day 1 Alice runs `gcp-foundation` to create folders, guardrails, KMS keys, networks, and BigQuery schemas.
Day 10 Bob runs `gcp-data-ingestion` to deploy Pub/Sub, Dataflow, and Datastream pipelines later.

Why avoid `terraform_remote_state` across teams and repositories?

- Terraform state stores every resource attribute, IAM binding, internal identifier, and sensitive output in plaintext JSON.
- Granting Bob read access to Alice's `tfstate` bucket leaks foundation state internals across trust boundaries.
- Changing internal resources in `gcp-foundation` also risks breaking remote state lookups in downstream repos.

How `00_linked.auto.tfvars.json` and `gs://<prefix>-iac-outputs` solve this:

- Stage 00 creates `<prefix>-<suffix>-tfstate` (locked to Alice) and `<prefix>-<suffix>-iac-outputs` (shared read-only for Bob).
- Alice runs `./scripts/link-stages.sh --env dev --export-gcs gs://<bucket>/<stage>.json <stage1> <stage2>` after apply.
- The script strips `sensitive = true` and `null` values before uploading clean JSON to GCS.
- Bob runs `./scripts/link-stages.sh --env dev --from-gcs gs://<bucket>/<stage>.json <target_stage_dir>` inside `gcp-data-ingestion`.
- The script keeps only variables declared in Bob's `variables.tf` and writes `00_linked.auto.tfvars.json` (`0600`).
- Alice's `.tfstate` remains locked inside `<prefix>-<suffix>-tfstate` at all times.

## Design Rules

- Every project disables default VPC creation (`auto_create_network = false`).
- Production projects set `deletion_policy = "PREVENT"` and folders set `deletion_protection = true`.
- Foundation stage 00 creates hardened `tfstate` and `iac-outputs` buckets plus scoped GitHub WIF.
- Foundation stage 01 locks the audit bucket, attaches a project lien, and enforces FinOps tags.
- Foundation stage 01 enforces a 36-policy Org Policy baseline when `enable_org_policies = true`.
- Foundation stage 02 configures CMEK, Shared VPC, Flow Logs, DNS logging, VPC-SC, and monitoring alerts.
- Stage 02 enforces a network firewall policy with PSC TCP 443 allow and default deny-all egress.
- Dataform ETL uses the custom `dataform_pipeline_runner` role without dataset update or delete rights.
- BigQuery slot reservations default to `slot_capacity = 0` with `ENTERPRISE` edition autoscaling.
- No stage shares Terraform state; stages pass outputs through `scripts/link-stages.sh` into `00_linked.auto.tfvars.json`.
