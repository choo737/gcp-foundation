# Architecture Overview

This repository separates cloud foundation guardrails from data platform operations across independent Terraform state roots.

## Folder Topology

```text
organizations/<org_id> (or folders/<parent_id>)
└── <prefix>-gcp-foundation
    ├── 01-shared-infrastructure
    │   ├── <prefix>-audit
    │   └── <prefix>-network
    └── 02-workloads
        └── data-platform
            ├── storage
            │   ├── <prefix>-data-gov
            │   ├── <prefix>-data-core
            │   └── <prefix>-data-<domain>
            └── compute
                ├── <prefix>-data-etl
                └── <prefix>-data-bi
```

## Five-Project Data Separation

| Project | Layer | Responsibility |
| --- | --- | --- |
| `data-gov` | Governance | Data Catalog taxonomy, policy tags, `LAST_FOUR_CHARACTERS` masking, Dataplex glossary |
| `data-core` | Storage | Versioned landing bucket, `bronze_raw`, `silver_curated`, `silver_assertions` |
| `data-<domain>` | Storage | Domain-scoped `gold_mart` datasets such as `fin` |
| `data-etl` | Compute | Dataform repository, ETL SA, `ops_telemetry`, BigQuery slot reservations |
| `data-bi` | Compute | Zero-table BI query project isolating analyst compute and billing |

## Design Rules

- Every project disables default VPC creation (`auto_create_network = false`).
- Production projects set `deletion_policy = "PREVENT"` and folders set `deletion_protection = true`.
- Foundation stage 01 configures FinOps monthly budgets, `billing_export` dataset, and cost-allocation tags.
- Foundation stage 02 configures regional CMEK and optional private `googleapis.com` PSC DNS.
- BigQuery slot reservations default to `slot_capacity = 0` with `ENTERPRISE` edition autoscaling.
- No stage shares Terraform state; stages pass outputs through `scripts/link-stages.sh` into `00_linked.auto.tfvars.json`.
