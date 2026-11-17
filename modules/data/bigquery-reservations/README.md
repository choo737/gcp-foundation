# BigQuery Reservations Module

This module provisions autoscaling BigQuery slot reservations and assigns query projects.

## Resources Managed

- `google_bigquery_reservation` with optional autoscaling, zero baseline slots, and optional `secondary_location` (`ENTERPRISE_PLUS`).
- `google_bigquery_reservation_assignment` binding target project IDs with `job_type = "QUERY"`.

## Usage

```hcl
module "reservations" {
  source = "../../modules/data/bigquery-reservations"

  project_id = var.admin_project_id
  region     = var.region
  prefix     = "bqfnd"

  reservations = {
    analytics = {
      edition       = "ENTERPRISE"
      slot_capacity = 0
      max_slots     = 100
    }
  }

  assignments = {
    (var.consumer_project_id) = "analytics"
  }
}
```
