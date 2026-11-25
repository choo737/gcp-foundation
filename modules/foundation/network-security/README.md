# Network Security Module

This module provisions regional CMEK keys, Shared VPC, PSC, Cloud NGFW policies, and VPC-SC controls.

## Resources Managed

- Primary and optional DR `google_kms_key_ring` and `google_kms_crypto_key` resources.
- Optional Shared VPC host, private subnet with Flow Logs, and Datastream PSC attachment.
- Optional PSC endpoint with private DNS zones for `googleapis.com.`, `pkg.dev.`, and `gcr.io.`.
- Optional folder `google_compute_firewall_policy` with threat intel deny, IAP, health checks, and `goto_next`.
- IAM-governed `GCE_FIREWALL` secure tags (`tier` and `access`) wired to VPC firewall rules.
- VPC Global Network Firewall Policy with PSC TCP 443, FQDN egress allowlist, and NGFW Enterprise opt-in.
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
