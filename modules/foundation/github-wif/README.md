# GitHub Workload Identity Federation Module

This module creates a keyless GitHub Actions Workload Identity Pool and OIDC provider.

## Resources Managed

- `google_iam_workload_identity_pool` scoped to the bootstrap project.
- `google_iam_workload_identity_pool_provider` trusting `https://token.actions.githubusercontent.com`.
- Mandatory CEL `attribute_condition` restricting org, repository, ref, and environment claims.
- Non-authoritative `roles/iam.workloadIdentityUser` bindings per repository and service account.

## Usage

```hcl
module "github_wif" {
  source = "../../modules/foundation/github-wif"

  project_id           = "seed-admin-project"
  prefix               = "ent"
  github_org           = "acme-corp"
  github_repositories  = ["acme-corp/gcp-foundation"]
  allowed_refs         = ["refs/heads/main", "refs/tags/*"]
  allowed_environments = ["dev", "staging", "prod"]
}
```
