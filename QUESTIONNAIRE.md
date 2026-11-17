# Tier-2 Foundation and Data Platform Questionnaire

Use this questionnaire to convert business, regulatory, and network choices into exact Terraform `.tfvars` values.
Users and coding agents can start here directly or import gitignored `platform-context.json` from `https://github.com/choo737/gcp-launchpad`.

## Handoff From Launchpad (`platform-context.json`)

If `platform-context.json` exists in the repository root, read it before asking repeated questions.
Treat `platform-context.json` as local intake state only and never commit it to Git.

| Handoff Field | Maps To Stage Variable | Notes |
| --- | --- | --- |
| `adoption_mode` | Adoption path (`Path 0`..`Path 3`) | `greenfield` runs `Path 0`..`1`; `brownfield` inspects `existing_landing_zone` |
| `compliance_profile` | Section 2 profile | `sandbox_poc`, `enterprise_standard`, or `regulated_fsi_rmit` |
| `primary_region` / `dr_region` | `region` / `dr_region` | Primary `asia-southeast1` and optional DR `asia-southeast2` |
| `environments` | Active `envs/<env>.tfvars` tiers | List such as `["dev", "staging", "prod"]` |
| `prefix` / `project_suffix` | `prefix` / `project_suffix` | `3-8` char prefix plus suffix like `dev01` |
| `ci_identity_mode` | `foundation/00-bootstrap` WIF toggle | `github_oidc_wif` enables WIF with `github_owner` |
| `finops.*` | Section 5 FinOps inputs | `create_dedicated_finops_project`, export location, budgets, thresholds |
| `backup_dr.*` | Section 2 Backup and DR inputs | `enable_backup_dr`, retention days, vault lock, soft delete, `bq_dr_mode` |
| `ngfw.*` | Section 4 NGFW flags | Hierarchical policy, standard rules, secure tags, `enable_ngfw_enterprise` |
| `scc.*` | Section 3 SCC settings | `scc_tier`, `scc_scope`, `enable_audit_cmek`, alerts, `runtime_detectors` |

Collect `parent_id`, `data_folder_id`, and `billing_account` directly because `platform-context.json` omits org and billing IDs.

## 1. Adoption Entry Path (`Path 0`..`Path 3`)

Pick the lowest-friction entry point matching your permissions and existing landing zone.

| Path | Scenario | Starting & Downstream Stages | Key Required Inputs |
| --- | --- | --- | --- |
| `Path 0` | Greenfield bootstrap seed | `foundation/00-bootstrap` | `project_id`, `region`, `prefix`, `project_suffix`, `ci_repository_map` |
| `Path 1` | Greenfield org or top folder | `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` | `parent_id`, `billing_account`, `environments`, `scc_tier`, `enable_org_policies` |
| `Path 2` | Brownfield data folder | `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` | `data_folder_id`, `billing_account`, optional `kms_key_id`, `shared_vpc_host_project_id`, `vpc_id`, `subnet_id` |
| `Path 3` | Single-project sandbox | `data/sandbox` | `project_id`, `region`, `prefix`, `masked_readers` |

- Confirm `Path 0` first if CI/CD needs GCS state buckets and scoped GitHub Actions WIF.
- In `Path 2`, reuse existing `storage_folder_id`, `compute_folder_id`, `kms_key_id`, or Shared VPC IDs when present.
- In `Path 2`, leave `vpc_id` and `kms_key_id` empty to deploy standalone datasets with Google-managed keys.

## 2. Regulatory, Retention & Backup DR Profile

Choose one baseline profile per environment (`sandbox_poc`, `enterprise_standard`, or `regulated_fsi_rmit`).
BNM RMiT and regulated FSI workloads require seven-year audit retention, HSM keys, and secondary DR coverage.

| Variable | Stage Root | `sandbox_poc` | `enterprise_standard` | `regulated_fsi_rmit` |
| --- | --- | --- | --- | --- |
| `retention_days` | `foundation/01-org-governance` | `30` | `1095` | `2555` |
| `lock_audit_bucket` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `enable_audit_project_lien` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `enable_audit_cmek` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `audit_kms_protection_level` | `foundation/01-org-governance` | `"SOFTWARE"` | `"SOFTWARE"` | `"HSM"` |
| `enable_org_policies` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `enable_data_access_audit_logs` | `foundation/01-org-governance` | `true` | `true` | `true` |
| `create_dedicated_finops_project` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `enable_backup_dr` | `foundation/01-org-governance` | `false` | `true` | `true` |
| `backup_enforced_retention_days` | `foundation/01-org-governance` | `14` | `14` | `30` |
| `lock_backup_vault` | `foundation/01-org-governance` | `false` | `false` | `false` (`true` at prod cutover) |
| `kms_protection_level` | `foundation/02-security-network` | `"SOFTWARE"` | `"SOFTWARE"` | `"HSM"` |
| `dr_region` | `01-org-governance`, `02-security-network`, `01-platform` | `null` | `""` | `"asia-southeast2"` |
| `soft_delete_retention_seconds` | `00-bootstrap`, `01-platform`, `data/sandbox` | `604800` | `1209600` (14d) | `2592000` (30d) |
| `enable_dual_region_gcs` | `data/enterprise/01-platform` | `false` | `false` | `true` (`ASYNC_TURBO`) |
| `reservation_edition` | `data/enterprise/01-platform` | `"ENTERPRISE"` | `"ENTERPRISE"` | `"ENTERPRISE_PLUS"` |
| `enable_dr_datasets` | `data/enterprise/01-platform` | `false` | `false` | `false` (native DR) |
| `deletion_protection` | `01-org-governance`, `01-platform` | `false` | `false` (`dev`) / `true` (`staging`, `prod`) | `false` (`dev`) / `true` (`staging`, `prod`) |
| `project_deletion_policy` | `01-org-governance`, `02-security-network`, `01-platform` | `"DELETE"` | `"DELETE"` (`dev`) / `"PREVENT"` (`prod`) | `"PREVENT"` |
| `delete_contents_on_destroy` | `01-org-governance`, `01-platform`, `02-governance-ops`, `data/sandbox` | `true` | `true` (`dev`) / `false` (`prod`) | `false` |
| `immutable_image_tags` | `data/enterprise/01-platform`, `data/sandbox` | `false` | `false` (`dev`) / `true` (`prod`) | `true` |

- When `enable_org_policies = true`, provide `allowed_policy_member_domains` and `allowed_contact_domains`.
- Never enable `lock_audit_bucket = true` on short-lived tests unless you follow decommission steps.
- Use `gcs_rpo = "ASYNC_TURBO"` only when critical buckets require the contractual 15-minute [Cloud Storage SLA](https://cloud.google.com/storage/sla).
- Confirm cross-border `asia-southeast1` + `asia-southeast2` replication is permitted under BNM RMiT before enabling dual-region buckets.
- Keep `enable_dr_datasets = false` and use `scripts/configure-bq-dr-replica.sh` plus `ENTERPRISE_PLUS` `reservation_secondary_location` for BigQuery DR.

## 3. Security Command Center & Posture (`foundation/01-org-governance`)

Select the SCC tier and scope matching your budget, compliance posture, and organization permissions. Note that `SCC Enterprise` retires May 21, 2027.

| `scc_tier` | Cost Tier | Deployed Controls & Outputs | Required Extra Variables |
| --- | --- | --- | --- |
| `"NONE"` | None | Skips SCC module and exports | None |
| `"STANDARD"` | Free tier | Regional `asia-southeast1` BigQuery export, `dev`/`staging` mute rules, CMEK Pub/Sub topic, Monitoring alerts | `scc_alert_email_addresses`, `scc_location` (`"global"`) |
| `"PREMIUM"` | Paid tier | Includes `STANDARD`, adds `prod` BigQuery CMEK and GCS UBLA Custom SHA detectors, ETD, and Posture | `scc_alert_email_addresses`, `enable_security_posture`, `organization_id` |

- Set `scc_scope = "FOLDER"` for org or folder deployments, or `"PROJECT"` for standalone PAYG projects.
- Keep `scc_location = "global"` unless data residency requires `"us"`, `"eu"`, or `"sa"`.
- BigQuery SCC findings export always stores tables in `region` (such as `asia-southeast1`).
- Set `organization_id = "organizations/<YOUR_ORG_ID>"` when `parent_id` is a folder and `enable_security_posture = true`.
- Set `scc_siem_push_endpoint` to push HIGH and CRITICAL findings directly to an external HTTPS SIEM webhook.
- Run `./scripts/verify-scc-detectors.sh` after apply to verify built-in ETD, Container, VM, and Cloud Run detectors.

## 4. Network, Cloud NGFW & VPC-SC

Configure network isolation, Cloud NGFW layering, and VPC-SC across `foundation/02-security-network` and `data/enterprise/01-platform`.

| Control Area | Variables (`02-security-network`) | Linked Variables (`01-platform`) | Recommended Rollout |
| --- | --- | --- | --- |
| Shared VPC & Logs | `enable_vpc`, `enable_shared_vpc_host`, `subnet_cidr` (`"10.20.0.0/20"`), `enable_vpc_flow_logs`, `vpc_flow_logs_sampling`, `enable_dns_logging` | `shared_vpc_host_project_id`, `vpc_id`, `subnet_id` | `enable_shared_vpc_host = true` in enterprise envs |
| Private Google APIs | `enable_psc`, `psc_ip_address` (`"10.250.0.10"`) | Inherited via Shared VPC DNS | Enable with custom VPC |
| Datastream & Private DBs | `enable_datastream_psc_attachment`, `datastream_nat_subnet_cidr`, `datastream_producer_accept_lists`, `allowed_private_db_cidrs` | `datastream_network_attachment_id` | Supply private DB CIDRs for TCP `5432`/`3306` |
| Cloud NGFW Layering | `enable_hierarchical_firewall_policy`, `enable_ngfw_standard_rules`, `enable_secure_tags`, `allowed_egress_fqdns` | Applied across environment folders | Enable folder policy and threat intel deny in `prod` |
| NGFW Enterprise Opt-In | `enable_ngfw_enterprise`, `organization_id`, `ngfw_enterprise_zones`, `enable_ngfw_tls_inspection` | Zero-rewrite VPC attachment | Opt in when L7 IPS inspection is required |
| VPC Service Controls | `enable_vpc_sc`, `enforce_vpc_sc`, `access_policy_id`, `perimeter_project_numbers`, `vpc_sc_ingress_principals`, `vpc_sc_audit_project_number`, `vpc_sc_access_level_members` | `vpc_sc_perimeter_name`, `enforce_vpc_sc` | `enforce_vpc_sc = false` (`dev`/`staging`), `true` (`prod`) |

- Start every environment with `enable_vpc_sc = true` and `enforce_vpc_sc = false` (`DRY_RUN`).
- Review dry-run logs and add missing principals before flipping `enforce_vpc_sc = true` in `prod`.
- Review [Firewall Tiers](https://cloud.google.com/security/products/firewall) and [Firewall Pricing](https://cloud.google.com/firewall/pricing) before enabling `enable_ngfw_enterprise = true` for IPS or TLS inspection.
- `data/enterprise/02-governance-ops` also reads `vpc_sc_perimeter_name` and `enforce_vpc_sc` for Dataform ingress.

## 5. FinOps Budgets, BigQuery Slots & RBAC Groups

Size dedicated FinOps billing exports, multi-tier budgets, BigQuery reservations, Google Groups, and scoped GitHub WIF allowlists.

### FinOps Project, Export & Budgets (`foundation/01-org-governance`)

| Variable | Default | Purpose | Notes |
| --- | --- | --- | --- |
| `create_dedicated_finops_project` | `true` | Provisions `<prefix>-cmn-finops` under shared infra | Set `false` for `sandbox_poc` co-location |
| `finops_billing_export_location` | `"US"` | BigQuery export location | `"US"` or `"EU"` gets 2-month backfill |
| `enable_billing_budget` | `true` | Creates Cloud Billing budgets | Alert-only; zero auto-kill |
| `monthly_budget_amount` | `500` | Master monthly threshold in whole currency units | Alerts at 50%, 80%, 90%, 100%, and 100% forecast |
| `environment_budgets` | `{}` | Map of env name to monthly budget amount | Scoped to `02-environments/<env>` folders |
| `workload_budgets` | `{}` | Map of workload budgets by project or label | Supports custom per-workload `alert_emails` |
| `finops_alert_email_addresses` | `[]` | Up to 5 Monitoring email channels | Use group emails like `gcp-finops-alerts@<domain>` |
| `budget_currency_code` | `"USD"` | ISO-4217 currency code | Match Cloud Billing account currency |
| `budget_project_numbers` | `[]` | Optional numeric project filter list | Empty scopes the whole billing account |
| `enable_finops_tag_bindings` | `true` | Binds `cost_center` and `environment` tags | Propagates tags to downstream projects |

- Follow [Billing Export Setup](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-setup) and [Billing Export Guide](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery) when choosing `"US"` backfill versus `"asia-southeast1"` regional residency.
- Complete the one-time Cloud Console Billing Export toggle after Terraform creates `<prefix>_billing_export`.

### BigQuery Slot Reservations (`data/enterprise/01-platform`)

All three pools (`etl`, `bi`, `adhoc`) use `reservation_edition` (`"ENTERPRISE"` default, `"ENTERPRISE_PLUS"` for DR) when `enable_reservations = true`.

| Environment | `enable_reservations` | `baseline_slots` / `max_slots` | Pool Overrides (`etl` / `bi` / `adhoc`) |
| --- | --- | --- | --- |
| `dev` / `staging` | `true` (or `false` if no quota) | `0` / `100` | `etl_max_slots = 100`, `bi_max_slots = 100`, `adhoc_max_slots = 100` |
| `prod` | `true` | `50` / `400` | `etl` `50`/`400`, `bi` `50`/`400`, `adhoc` `0`/`200` |

### RBAC Google Groups & Multi-Repo WIF Scoping

| Scope | Stage Root | Variable Name | Expected Entries |
| --- | --- | --- | --- |
| Foundation Ops | `foundation/01-org-governance` | `foundation_iam_groups` | `audit_viewer`, `security_reviewer`, `network_viewer`, `billing_viewer` |
| Essential Contacts | `foundation/01-org-governance` | `essential_contacts` | Security and legal contact emails and categories |
| Data Platform Groups | `data/enterprise/01-platform` | `bi_analysts_group`, `data_engineers_group`, `governance_stewards_group`, `break_glass_admins_group` | Google Group emails for BI, ETL, governance, and break-glass |
| PII Readers | `data/enterprise/01-platform`, `data/sandbox` | `masked_readers`, `fine_grained_readers`, `bi_analysts` | IAM members for masked vs unmasked BigQuery reads |
| Multi-Repo CI WIF | `foundation/00-bootstrap` | `ci_repository_map` | Keys `tf_foundation_ci`, `tf_ingestion_ci`, `dataform_ci` mapped to `owner/repo` lists |

- Set `ci_repository_map` in `foundation/00-bootstrap` to prevent cross-repo service account impersonation.
- Restrict WIF tokens further with `github_org`, `github_repositories`, `allowed_refs`, and `allowed_environments`.

## 6. Write Customer Variables and Link Stages

Write answers into gitignored `custom.auto.tfvars` or tracked `envs/<env>.tfvars` inside private customer repos. Keep `terraform.tfvars` and `*.auto.tfvars*` gitignored.

```bash
./scripts/link-stages.sh --env dev foundation/01-org-governance foundation/02-security-network
./scripts/link-stages.sh --env dev foundation/01-org-governance foundation/02-security-network data/enterprise/01-platform
./scripts/link-stages.sh --env dev data/enterprise/01-platform data/enterprise/02-governance-ops
```

- Follow [docs/04-multi-env-and-decommission.md](docs/04-multi-env-and-decommission.md) before promoting to `prod` or tearing down protected stages.
