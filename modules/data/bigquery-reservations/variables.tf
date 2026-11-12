variable "project_id" {
  type        = string
  description = "Admin project ID that owns the BigQuery reservations."
}

variable "region" {
  type        = string
  description = "BigQuery location for reservations and assignments."
}

variable "prefix" {
  type        = string
  description = "Name prefix for created BigQuery reservations."
}

variable "bi_project_id" {
  type        = string
  default     = ""
  description = "Optional BI compute project ID automatically assigned to the adhoc reservation."
}

variable "reservations" {
  type = map(object({
    edition           = optional(string, "ENTERPRISE")
    slot_capacity     = optional(number, 0)
    ignore_idle_slots = optional(bool, false)
    max_slots         = optional(number, 100)
  }))
  default     = {}
  description = "Map of BigQuery reservations keyed by short reservation name."

  validation {
    condition     = alltrue([for r in values(var.reservations) : r.max_slots == null ? true : (r.max_slots >= 0 && r.max_slots % 50 == 0)])
    error_message = "Autoscale max_slots must be null or a non-negative multiple of 50."
  }
}

variable "assignments" {
  type        = map(string)
  default     = {}
  description = "Map of assignee project IDs to reservation keys in var.reservations."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to BigQuery reservations."
}
