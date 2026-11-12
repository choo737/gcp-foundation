# Network Security Module

This module provisions regional CMEK keys and optional VPC, PSC, DNS, and VPC-SC controls.

## Resources Managed

- Regional `google_kms_key_ring` and `google_kms_crypto_key` with 90-day rotation and 30-day schedule.
- Optional custom VPC, private subnet with VPC Flow Logs, and Cloud DNS query logging.
- Optional PSC endpoint with private DNS zones for `googleapis.com.`, `pkg.dev.`, and `gcr.io.`.
- Network firewall policy allowing TCP 443 to PSC with a priority 65530 deny-all egress rule.
- Optional `google_access_context_manager_service_perimeter` supporting dry-run or enforced mode.

## Usage

```hcl
module "network_security" {
  source = "../../modules/foundation/network-security"

  project_id  = module.network_project.project_id
  region      = var.region
  prefix      = "ent"
  enable_cmek = true
  enable_vpc  = false
}
```
