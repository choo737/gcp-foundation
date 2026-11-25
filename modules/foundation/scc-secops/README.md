# Security Command Center SecOps Module

This module wires Security Command Center v2 exports, alerts, mute rules, and posture guardrails.

Google retires the SCC Enterprise tier on May 21, 2027.
Only `STANDARD` (free) and `PREMIUM` (paid) remain active tiers.

## Tier Capabilities

| Tier | Capabilities Enabled |
| --- | --- |
| `NONE` | Creates zero resources |
| `STANDARD` | Regional BigQuery export, Pub/Sub topic (CMEK-capable), Monitoring alert, non-prod mute rules |
| `PREMIUM` | All `STANDARD` resources plus Custom SHA CEL modules, optional ETD module, and Security Posture |

## Scope Modes and Alerting

- `scc_scope = "ORGANIZATION"` creates organization-level exports, notification configs, non-prod mute rules, and org SHA modules.
- `scc_scope = "FOLDER"` creates folder-level exports, notifications, mute rules, and SHA modules. Organization parents switch these to org scope.
- `scc_scope = "PROJECT"` creates project-level PAYG exports, notification configs, and SHA modules for `scc_target_project_ids`.
- Monitoring alerts track `pubsub.googleapis.com/topic/send_message_operation_count` with `auto_close = "1800s"`.
- Optional `siem_push_endpoint` adds a Pub/Sub `push_config` onto the findings subscription.

## Usage

```hcl
module "scc_secops" {
  source = "../../modules/foundation/scc-secops"

  scc_tier               = "STANDARD"
  scc_scope              = "FOLDER"
  scc_location           = "global"
  folder_id              = module.folder_hierarchy.root_folder_id
  environment_folder_ids = module.folder_hierarchy.environment_folder_ids
  audit_project_id       = module.audit_project.project_id
  kms_key_id             = google_kms_crypto_key.audit_cmek[0].id
  prefix                 = "ent"
  region                 = var.region
  alert_email_addresses  = ["secops@example.com"]
}
```
