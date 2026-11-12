variable "project_id" {
  type        = string
  description = "GCP project ID hosting Cloud Monitoring channels, log metrics, and alert policies."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to monitoring alert policies and channels."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (for example dev, staging, prod)."
}

variable "enable_alerts" {
  type        = bool
  default     = true
  description = "Whether to provision Cloud Monitoring notification channels and alert policies."
}

variable "alert_email_addresses" {
  type        = list(string)
  default     = []
  description = "Email addresses notified by Cloud Monitoring alert policies."
}

variable "alert_pubsub_topic_id" {
  type        = string
  default     = ""
  description = "Optional Pub/Sub topic resource ID for programmatic alert routing."
}

variable "dlq_backlog_threshold" {
  type        = number
  default     = 0
  description = "Maximum undelivered Pub/Sub DLQ messages allowed before firing an alert."
}

variable "bigquery_slot_threshold" {
  type        = number
  default     = 100
  description = "BigQuery allocated slot threshold before firing a saturation alert."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "User labels attached to notification channels and alert policies."
}
