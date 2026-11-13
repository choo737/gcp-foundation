# Security Command Center SecOps Module

This module wires Security Command Center v2 exports, alerts, mute rules, and posture guardrails.

Google deprecated the SCC Enterprise tier in May 2026.
Only `STANDARD` (free) and `PREMIUM` (paid) remain active tiers.

## Tier Capabilities

| Tier | Capabilities Enabled |
| --- | --- |
| `NONE` | Creates zero resources |
| `STANDARD` | Regional BigQuery export, Pub/Sub streaming, Monitoring alert, non-prod mute rules |
| `PREMIUM` | All `STANDARD` resources plus Custom SHA CEL modules and Security Posture |

## API Location and Data Residency

SCC v2 APIs accept `global`, `us`, `eu`, or `sa` for `scc_location`.
BigQuery findings export still stores exported rows regionally in `var.region` (`asia-southeast1`).

## Usage

```hcl
module "scc_secops" {
  source = "../../modules/foundation/scc-secops"

  scc_tier               = "STANDARD"
  scc_location           = "global"
  folder_id              = module.folder_hierarchy.root_folder_id
  environment_folder_ids = module.folder_hierarchy.environment_folder_ids
  audit_project_id       = module.audit_project.project_id
  prefix                 = "ent"
  region                 = var.region
  alert_email_addresses  = ["secops@example.com"]
}
```
