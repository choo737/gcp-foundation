# Security Foundations Blueprint Alignment

This repository maps directly to all seven chapters of the Google Cloud Security Foundations Blueprint.

## 1. Authentication and Authorization

Federate workforce identities from your corporate IdP into Cloud Identity or Google Workspace.
Bind IAM permissions to Google Groups rather than individual user accounts.
Enforce phishing-resistant MFA on all human administrator and break-glass accounts.

| Team Role | Group / Variable | Stage | Granted Access |
| --- | --- | --- | --- |
| CloudOps Admins | `foundation_iam_groups.cloudops_admins` | `01-org-governance` | Folder viewer, monitoring viewer, audit log viewer, Golden AR `repoAdmin` |
| Network Admins | `network_admins_group` | `02-security-network` | `roles/compute.networkAdmin` and `roles/dns.admin` on network project |
| Security Admins | `foundation_iam_groups.security_admins`, `security_admins_group` | `01-org-governance`, `02-security-network` | Security reviewer, Org Policy viewer, KMS viewer (CI-gated mutations) |
| SecOps Analysts | `foundation_iam_groups.secops_analysts` | `01-org-governance` | Audit log viewer and BigQuery viewer/jobUser on `cmn-secops` |
| FinOps Admins | `foundation_iam_groups.finops_admins` | `01-org-governance` | `roles/billing.costsManager` plus BigQuery viewer/jobUser on `cmn-finops` |
| Data Platform Teams | `data_engineers_group`, `bi_analysts_group`, `governance_stewards_group` | `01-platform` | Scoped ETL, BI `jobUser` + `maskedReader`, and Data Catalog stewardship |
| AI & ML Teams | `ai_admins_group`, `ds_analysts_group` | `03-data-science` | Viewer on `ds-exp` and `ml-ops`; SoD splits experimentation from MLOps |
| App Teams | `app_admins_group`, `admin_group`, `developer_group`, `env_groups` | `apps/enterprise` | Admin/developer access in non-prod; read-only logs/monitoring in `prod` |

## 2. Organization Structure

Use `environments/<env>/<department>` as the primary `[Folder]` and `[Project]` hierarchy.

```text
Root [Folder]: <prefix>-<suffix>-gcp-foundation
├── shared-infrastructure [Folder]
│   ├── <prefix>-<suffix>-audit [Project] (CloudOps / Security)
│   ├── <prefix>-<suffix>-cmn-secops [Project] (SecOps Analysts)
│   ├── <prefix>-<suffix>-cmn-finops [Project] (FinOps Admins)
│   └── <prefix>-<suffix>-cmn-backup [Project] (CloudOps Admins)
└── environments [Folder]
    └── {dev, uat, staging, prod} [Folder]
        ├── <prefix>-<suffix>-network [Project] (Network Admins)
        ├── data-platform [Folder] -> storage / compute (Data Teams)
        ├── ai [Folder] -> ds-exp / ml-ops (AI Teams)
        └── app [Folder] -> <app_unit> -> <prefix>-<suffix>-app-<key> (App Teams)
```

Why `Environment -> Department` prevents `prod` IAM leaks:

- IAM roles inherit strictly downward through the Resource Manager folder tree.
- Placing `<env>` above `<department>` isolates `prod` under one boundary.
- Granting a non-prod QA or developer role on `dev` or `uat` cannot reach `prod`.
- Applying stricter Org Policies or VPC-SC on `prod` never breaks `dev`.

Comparison with `Department -> Environment`:

- `Department -> Environment` groups `dev` and `prod` under one department folder.
- Any folder-level grant on a department folder automatically grants access to `prod`.
- That model requires extra deny policies or conditional IAM to prevent drift.
- Use `Environment -> Department` as the default for regulated enterprises.

## 3. Networking

Each environment deploys one dedicated network host project (`<prefix>-<suffix>-network`).
Enable `enable_shared_vpc_host = true` to centralize routing, DNS, and firewall governance.
Use `department_subnet_cidrs` to isolate `data`, `ai`, and `app` subnets inside the Shared VPC.
Enable Private Google Access (`private_ip_google_access = true`) and Private Service Connect for `googleapis.com`.
Enable VPC Flow Logs (`enable_vpc_flow_logs = true`) and Cloud DNS query logging (`enable_dns_logging = true`).
Bind `roles/compute.networkUser` strictly at subnet scope, never on the host project.

## 4. Detective Controls

Centralize folder audit logs in `<prefix>-audit-logs` with Log Analytics enabled.
Lock the audit log bucket (`lock_audit_bucket = true`) and protect the project with a lien.
Isolate SCC v2 exports in `<prefix>-<suffix>-cmn-secops` via `create_dedicated_secops_project = true`.
Stream HIGH and CRITICAL SCC findings to Pub/Sub and Cloud Monitoring email channels.
Optionally attach `enable_siem_pubsub_sink = true` and `scc_siem_push_endpoint` for external SIEM ingestion.

## 5. Preventative Controls

Enforce the 38-rule Org Policy baseline on the root folder via `enable_org_policies = true`.
Require Uniform Bucket-Level Access, disable service account keys, and restrict public IPs.
Deploy VPC Service Controls (`enable_vpc_sc = true`) starting in `DRY_RUN` (`enforce_vpc_sc = false`).
Promote `enforce_vpc_sc = true` only after verifying dry-run logs in Log Analytics.
Separate KMS key admin from crypto user roles via regional CMEK (`SOFTWARE` or `HSM`).
Cap human `env_groups` and `developer_group` bindings in `prod` to read-only logs and monitoring.

## 6. Deployment Methodology

Separate CI/CD pipelines across three layers using keyless GitHub Actions OIDC WIF:

1. **Layer 1 (Foundation Pipeline)**: `org_gov_ci` and `net_sec_ci` manage folders, guardrails, KMS, and VPCs.
2. **Layer 2 (Infrastructure & App Factory Pipeline)**: `data_plat_ci`, `tf_ds_ci`, and `tf_app_ci` provision projects.
3. **Layer 3 (Workload Pipelines)**: `tf_ingestion_ci`, `dataform_ci`, and app repos deploy runtime workloads.

Scope every WIF provider with CEL conditions on `repository_owner`, `repository`, and `environment`.
Exchange non-sensitive outputs via `scripts/link-stages.sh` and `iac-outputs`, never shared `.tfstate`.

## 7. Operations Best Practices

Tag every project with `cost_center` (`platform`, `shared`, `data`, `ai`, `app`, `security`, `network`) and `environment`.
Configure master, per-environment, and `department_budgets` with `finops_billing_export_table_name` for `v_finops_department_spend`.
Enable `enable_shared_artifact_registry = true` for central golden base container images.
Enable `enable_backup_dr = true` for immutable Backup Vaults and daily GCE or Cloud SQL schedules.
Run `terraform plan` with `drift-safe-apply` checks before promoting changes across environments.
