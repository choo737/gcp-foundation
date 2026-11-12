# Monitoring Alerts Module

This module creates Cloud Monitoring notification channels and five data platform alert policies.

## Resources Managed

- Optional email and Pub/Sub `google_monitoring_notification_channel` targets.
- `google_logging_metric` tracking Dataform API errors (`severity>=ERROR`).
- Five `google_monitoring_alert_policy` rules for DLQ, Workflows, Cloud Run, BigQuery slots, and Dataform.

## Usage

```hcl
module "monitoring_alerts" {
  source = "../../modules/foundation/monitoring-alerts"

  project_id            = module.network_project.project_id
  prefix                = "ent"
  environment           = "prod"
  alert_email_addresses = ["alerts@example.com"]
}
```
