variable "project_id" {
  type        = string
  description = "Bootstrap or seed GCP project ID hosting the Workload Identity Pool."
}

variable "prefix" {
  type        = string
  description = "Prefix for Workload Identity Pool and OIDC provider IDs."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}[a-z0-9]$", var.prefix)) && !startswith(var.prefix, "gcp-")
    error_message = "prefix must be 2-16 lowercase alphanumeric/hyphen chars and must not start with gcp-."
  }
}

variable "github_org" {
  type        = string
  default     = ""
  description = "GitHub organization or owner login enforced in the CEL attribute condition."

  validation {
    condition     = var.github_org == "" || can(regex("^[A-Za-z0-9-]+$", var.github_org))
    error_message = "github_org must match ^[A-Za-z0-9-]+$ to prevent CEL injection."
  }
}

variable "github_repositories" {
  type        = list(string)
  default     = []
  description = "Authorized GitHub repositories (owner/repo) allowed in the CEL attribute condition."

  validation {
    condition     = alltrue([for r in var.github_repositories : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", r))])
    error_message = "Each github_repositories entry must match owner/repo using safe characters only."
  }
}

variable "allowed_refs" {
  type        = list(string)
  default     = []
  description = "Optional Git refs or wildcard prefixes (for example refs/heads/main, refs/tags/*) enforced in CEL."

  validation {
    condition     = alltrue([for r in var.allowed_refs : can(regex("^[A-Za-z0-9._/*-]+$", r))])
    error_message = "Each allowed_refs entry must match ^[A-Za-z0-9._/*-]+$."
  }
}

variable "allowed_environments" {
  type        = list(string)
  default     = []
  description = "Optional GitHub Environments (for example dev, staging, prod) enforced in CEL."

  validation {
    condition     = alltrue([for e in var.allowed_environments : can(regex("^[a-z0-9-]+$", e))])
    error_message = "Each allowed_environments entry must match ^[a-z0-9-]+$."
  }
}

variable "service_account_bindings" {
  type = map(object({
    service_account_id = string
    repositories       = list(string)
  }))
  default     = {}
  description = "Optional map of service account resource names to allowed GitHub repositories for WIF impersonation."

  validation {
    condition = alltrue(flatten([
      for _, cfg in var.service_account_bindings : [
        for r in cfg.repositories : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", r))
      ]
    ]))
    error_message = "Every repository in service_account_bindings must match owner/repo."
  }
}
