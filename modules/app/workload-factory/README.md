# Application Workload Factory Module

This module creates per-application folders, isolated GCP projects, subnet-scoped Shared VPC bindings, CMEK grants, and clean IAM roles.

## Resources Managed

- Per-application subfolder under the environment `app` folder.
- Application project via `modules/foundation/project-factory` tagged with `cost_center = app`.
- Shared VPC service project attachment and subnet-scoped `roles/compute.networkUser` grants.
- Cloud KMS EncrypterDecrypter grants for Cloud Run, GKE, Compute, Secret Manager, and Cloud SQL agents.
- Non-prod versus prod IAM roles preventing human production drift.
- Shared golden Artifact Registry `roles/artifactregistry.reader` grants.

## Usage

```hcl
module "workload_factory" {
  source = "../../modules/app/workload-factory"

  app_folder_id   = "folders/000000000000"
  billing_account = "000000-000000-000000"
  prefix          = "ent"
  environment     = "dev"
  applications = {
    web = {
      display_name     = "Web Portal"
      enable_cloud_run = true
    }
  }
}
```
