# Architecture Overview

This repository separates cloud foundation guardrails from data platform operations across independent Terraform state roots.

## Folder Topology

```text
organizations/<org_id> (or folders/<parent_id>)
└── <prefix>-gcp-foundation
    ├── 01-shared-infrastructure
    │   ├── <prefix>-fnd-audit
    │   └── <prefix>-fnd-netsec
    └── 02-workloads
        └── data-platform
            ├── storage
            │   ├── <prefix>-dp-gov
            │   ├── <prefix>-dp-st-core
            │   └── <prefix>-dp-st-<domain>
            └── compute
                ├── <prefix>-dp-cp-etl
                └── <prefix>-dp-cp-bi
```

## Five-Project Data Separation

| Project | Layer | Responsibility |
| --- | --- | --- |
| `dp-gov` | Governance | Data Catalog taxonomy, policy tags, `LAST_FOUR_CHARACTERS` masking, Dataplex glossary |
| `dp-st-core` | Storage | Versioned landing bucket, `bronze_raw`, `silver_curated`, `silver_assertions` |
| `dp-st-<domain>` | Storage | Domain-scoped `gold_mart` datasets such as `fin` |
| `dp-cp-etl` | Compute | Dataform repository, ETL SA, `ops_telemetry`, BigQuery slot reservations |
| `dp-cp-bi` | Compute | Zero-table BI query project isolating analyst compute and billing |

## Design Rules

- Every project disables default VPC creation (`auto_create_network = false`).
- Production projects set `deletion_policy = "PREVENT"` and folders set `deletion_protection = true`.
- Foundation stage 01 configures FinOps monthly budgets, `billing_export` dataset, and cost-allocation tags.
- Foundation stage 02 configures regional CMEK and optional private `googleapis.com` PSC DNS.
- BigQuery slot reservations default to `slot_capacity = 0` with `ENTERPRISE` edition autoscaling.
- No stage shares Terraform state; stages pass outputs through `scripts/link-stages.sh` into `00_linked.auto.tfvars.json`.
