# Cloudera to BigQuery Mapping

This guide maps common Cloudera Data Platform components to the Google Cloud resources deployed here.

## Component Mapping

| Cloudera Component | GCP Equivalent | Terraform Module |
| --- | --- | --- |
| HDFS Landing Zone | Cloud Storage Bucket (`uniform_bucket_level_access`) | `data/enterprise/01-platform` |
| Hive / Impala Databases | BigQuery Datasets (`bronze`, `silver`, `gold`) | `modules/data/bigquery-dataset` |
| Apache Ranger Tag Policies | Data Catalog Policy Tags + Masking Data Policy | `modules/data/governance-catalog` |
| Apache Atlas Glossary | Dataplex Business Glossary | `modules/data/governance-catalog` |
| Oozie / Spark Workflows | Dataform Repository + Release Config | `modules/data/dataform-repository` |
| YARN Capacity Scheduler | BigQuery Enterprise Slot Reservations (`etl`, `bi`) | `modules/data/bigquery-reservations` |
| Cloudera Audit / Navigator | Cloud Logging Folder Sink + Central Bucket | `modules/foundation/logging-guardrails` |
| Ranger KMS | Cloud KMS CMEK with 90-day Rotation | `modules/foundation/network-security` |

## Why Compute and Storage Projects Separate

- In Cloudera, YARN queues isolate ETL jobs from BI dashboards on shared hardware.
- In BigQuery, separate `data-etl` and `data-bi` compute projects isolate quotas and slot reservations.
- Data stays inside `data-core` and `data-<domain>`, so multiple compute projects query without copying tables.
