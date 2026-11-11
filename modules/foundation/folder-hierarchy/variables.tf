variable "parent_id" {
  type        = string
  description = "Parent resource ID formatted as organizations/<id> or folders/<id>."

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent_id))
    error_message = "parent_id must match organizations/<id> or folders/<id>."
  }
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to the optional root foundation folder."
}

variable "folder_suffix" {
  type        = string
  default     = ""
  description = "Optional suffix appended to the root folder display name for uniqueness."
}

variable "create_root_folder" {
  type        = bool
  default     = true
  description = "Whether to create a root wrapper folder under parent_id."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether Google Cloud prevents folder deletion during destroy."
}

variable "workload_folders" {
  type        = set(string)
  default     = ["data-platform"]
  description = "Workload pillar folder names created under 02-workloads."
}
