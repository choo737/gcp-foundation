# Network Security Module

This module provisions regional CMEK keys, Shared VPC, PSC, firewall, and VPC-SC controls.

## Resources Managed

- Primary and optional DR `google_kms_key_ring` and `google_kms_crypto_key` resources.
- Optional Shared VPC host, private subnet with Flow Logs, and Datastream PSC attachment.
- Optional PSC endpoint with private DNS zones for `googleapis.com.`, `pkg.dev.`, and `gcr.io.`.
- Network firewall policy allowing PSC TCP 443, optional DB ports, and default deny-all egress.
- Optional environment-scoped `google_access_context_manager_service_perimeter` and access level.

## Usage

```hcl
module "network_security" {
  source = "../../modules/foundation/network-security"

  project_id  = module.network_project.project_id
  region      = var.region
  prefix      = "ent"
  environment = "dev"
  enable_cmek = true
  enable_vpc  = false
}
```
