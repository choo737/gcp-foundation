locals {
  repo_list_cel = join(", ", [for r in var.github_repositories : "'${r}'"])

  attribute_condition = (
    var.github_org != "" && length(var.github_repositories) > 0
    ? "assertion.repository_owner == '${var.github_org}' && assertion.repository in [${local.repo_list_cel}]"
    : (
      length(var.github_repositories) > 0
      ? "assertion.repository in [${local.repo_list_cel}]"
      : (
        var.github_org != ""
        ? "assertion.repository_owner == '${var.github_org}'"
        : ""
      )
    )
  )

  sa_repo_pairs = merge([
    for binding_key, cfg in var.service_account_bindings : {
      for repo in cfg.repositories :
      "${binding_key}:${repo}" => {
        service_account_id = cfg.service_account_id
        repository         = repo
      }
    }
  ]...)
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.prefix}-github-pool"
  display_name              = substr("${var.prefix} GitHub Actions", 0, 32)
  description               = "Workload Identity Pool for GitHub Actions OIDC federation."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.prefix}-github-oidc"
  display_name                       = substr("${var.prefix} GitHub OIDC", 0, 32)
  description                        = "GitHub OIDC provider restricted by organization or repository CEL condition."

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = local.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  lifecycle {
    precondition {
      condition     = local.attribute_condition != ""
      error_message = "Set github_org or github_repositories so attribute_condition is never empty."
    }
  }
}

resource "google_service_account_iam_member" "wif_user" {
  for_each = local.sa_repo_pairs

  service_account_id = each.value.service_account_id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value.repository}"
}
