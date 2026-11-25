locals {
  effective_kms_key_id  = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek              = local.effective_kms_key_id != ""
  effective_vpc_id      = var.vpc_id != null ? trimspace(var.vpc_id) : ""
  effective_subnet_id   = var.subnet_id != null ? trimspace(var.subnet_id) : ""
  use_private_network   = local.effective_vpc_id != "" && local.effective_subnet_id != ""
  network_project_id    = try(regex("^projects/([^/]+)/global/networks/", local.effective_vpc_id)[0], "")
  trimmed_wb_sa         = var.workbench_runtime_sa_email != null ? trimspace(var.workbench_runtime_sa_email) : ""
  trimmed_xai_cron      = var.xai_quality_schedule_cron != null ? trimspace(var.xai_quality_schedule_cron) : ""
  dataset_prefix        = replace(var.prefix, "-", "_")
  shap_tolerance_string = format("%.5f", var.shap_additivity_tolerance)

  active_workbench_instances = var.enable_ds_workbench ? var.workbench_instances : {}
  ml_ops_runtime_services = toset(concat(
    [
      "pubsub.googleapis.com",
      "workflows.googleapis.com",
    ],
    var.manage_run_service ? ["run.googleapis.com"] : [],
  ))
}

resource "terraform_data" "validate_colab_compliance" {
  lifecycle {
    precondition {
      condition     = !(var.enable_colab_enterprise && var.compliance_profile == "regulated_fsi_rmit")
      error_message = "enable_colab_enterprise = true is blocked when compliance_profile is regulated_fsi_rmit."
    }
  }
}

resource "google_workbench_instance" "this" {
  for_each = local.active_workbench_instances

  project                    = var.ds_exp_project_id
  location                   = trimspace(each.value.zone) != "" ? trimspace(each.value.zone) : "${var.region}-a"
  name                       = trimsuffix(substr(lower("${var.prefix}-${var.environment}-${replace(each.key, "_", "-")}"), 0, 63), "-")
  instance_owners            = trimspace(each.value.owner_email) != "" ? [replace(trimspace(each.value.owner_email), "user:", "")] : null
  enable_deletion_protection = var.environment == "prod"
  deletion_policy            = var.environment == "prod" ? "PREVENT" : "DELETE"
  labels                     = var.labels

  gce_setup {
    machine_type         = each.value.machine_type
    disable_public_ip    = true
    enable_ip_forwarding = false

    shielded_instance_config {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }

    boot_disk {
      disk_size_gb    = tostring(each.value.boot_disk_size_gb)
      disk_type       = "PD_BALANCED"
      disk_encryption = local.use_cmek ? "CMEK" : "GMEK"
      kms_key         = local.use_cmek ? local.effective_kms_key_id : null
    }

    data_disks {
      disk_size_gb    = tostring(each.value.data_disk_size_gb)
      disk_type       = "PD_BALANCED"
      disk_encryption = local.use_cmek ? "CMEK" : "GMEK"
      kms_key         = local.use_cmek ? local.effective_kms_key_id : null
    }

    dynamic "network_interfaces" {
      for_each = local.use_private_network ? [1] : []
      content {
        network = local.effective_vpc_id
        subnet  = local.effective_subnet_id
      }
    }

    dynamic "service_accounts" {
      for_each = local.trimmed_wb_sa != "" ? [local.trimmed_wb_sa] : []
      content {
        email = service_accounts.value
      }
    }

    metadata = merge(
      each.value.metadata,
      {
        notebook-disable-root      = "true"
        notebook-disable-downloads = "true"
        notebook-disable-nbconvert = "true"
        notebook-disable-terminal  = "true"
        idle-timeout-seconds       = tostring(var.workbench_idle_timeout_seconds)
      },
    )
  }
}

resource "google_workbench_instance_iam_member" "owner_runner" {
  for_each = {
    for k, v in local.active_workbench_instances :
    k => v
    if trimspace(v.owner_email) != ""
  }

  project  = var.ds_exp_project_id
  location = google_workbench_instance.this[each.key].location
  name     = google_workbench_instance.this[each.key].name
  role     = "roles/notebooks.runner"
  member = (
    startswith(trimspace(each.value.owner_email), "user:") ||
    startswith(trimspace(each.value.owner_email), "serviceAccount:")
    ? trimspace(each.value.owner_email)
    : "user:${trimspace(each.value.owner_email)}"
  )
}

resource "google_colab_runtime_template" "this" {
  count = var.enable_colab_enterprise ? 1 : 0

  project      = var.ds_exp_project_id
  location     = var.region
  display_name = "${var.prefix}-${var.environment}-colab-runtime"
  description  = "Governed Colab Enterprise runtime template."
  labels       = var.labels

  machine_spec {
    machine_type = var.colab_machine_type
  }

  idle_shutdown_config {
    idle_timeout = "${var.workbench_idle_timeout_seconds}s"
  }

  shielded_vm_config {
    enable_secure_boot = true
  }

  dynamic "network_spec" {
    for_each = local.use_private_network ? [1] : []
    content {
      enable_internet_access = false
      network                = local.effective_vpc_id
      subnetwork             = local.effective_subnet_id
    }
  }

  dynamic "encryption_spec" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_spec.value
    }
  }

  depends_on = [terraform_data.validate_colab_compliance]
}

resource "google_artifact_registry_repository" "ml_cpr" {
  project       = var.ml_ops_project_id
  location      = var.region
  repository_id = "${var.prefix}-ml-cpr"
  description   = "Container registry for Agent Platform custom inference routines and SHAP containers."
  format        = "DOCKER"
  kms_key_name  = local.use_cmek ? local.effective_kms_key_id : null
  labels        = var.labels

  docker_config {
    immutable_tags = var.environment == "prod"
  }
}

resource "google_vertex_ai_metadata_store" "default" {
  provider = google-beta

  project     = var.ml_ops_project_id
  region      = var.region
  name        = "default"
  description = "Agent Platform ML Metadata Store for model lineage and artifact SHA-256 provenance."

  dynamic "encryption_spec" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_spec.value
    }
  }
}

resource "google_storage_bucket" "xai_worm" {
  project                     = var.ml_ops_project_id
  name                        = "${var.ml_ops_project_id}-xai-worm"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.delete_contents_on_destroy && var.environment != "prod"
  labels                      = var.labels

  retention_policy {
    retention_period = var.environment == "prod" ? var.xai_audit_retention_days * 86400 : 86400
    is_locked        = var.environment == "prod"
  }

  soft_delete_policy {
    retention_duration_seconds = 604800
  }

  dynamic "encryption" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      default_kms_key_name = encryption.value
    }
  }
}

resource "google_bigquery_dataset" "ml_xai_audit" {
  project                    = var.ml_ops_project_id
  dataset_id                 = "${local.dataset_prefix}_ml_xai_audit"
  friendly_name              = "${var.prefix} ML XAI Audit"
  description                = "Governed BigQuery dataset storing immutable regulated explainable AI decision ledgers."
  location                   = var.region
  max_time_travel_hours      = 168
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels

  dynamic "default_encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "ml_xai_audit_ledger" {
  project                  = var.ml_ops_project_id
  dataset_id               = google_bigquery_dataset.ml_xai_audit.dataset_id
  table_id                 = "ml_xai_audit_ledger"
  description              = "Regulated XAI decision audit ledger capturing model digests, logits, SHAP attributions, and adverse reasons."
  deletion_protection      = var.environment != "dev"
  require_partition_filter = true
  clustering               = ["serving_track", "model_id", "explained_class", "entity_id"]
  labels                   = var.labels

  time_partitioning {
    type  = "DAY"
    field = "decision_timestamp"
  }

  schema = jsonencode([
    {
      name        = "decision_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique decision or scoring request identifier."
    },
    {
      name        = "entity_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Entity or customer identifier scored by the model."
    },
    {
      name        = "decision_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "UTC timestamp when the model prediction and explanation were emitted."
    },
    {
      name        = "serving_track"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Serving track identifier (for example primary or shadow)."
    },
    {
      name        = "model_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Registered Agent Platform model identifier."
    },
    {
      name        = "model_version_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Registered Agent Platform model version identifier."
    },
    {
      name        = "model_artifact_sha256"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "SHA-256 digest of the serialized model artifact."
    },
    {
      name        = "container_image_digest"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Immutable Artifact Registry container image digest."
    },
    {
      name        = "schema_version"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Feature and explanation payload contract version."
    },
    {
      name        = "explained_class"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Target class label explained by SHAP logits."
    },
    {
      name        = "approve_prob"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Predicted positive class probability."
    },
    {
      name        = "raw_margin"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Raw model margin in log-odds space before link transformation."
    },
    {
      name        = "base_logit"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "SHAP expected baseline value in log-odds space."
    },
    {
      name        = "shap_sum_logit"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Sum of feature SHAP attributions in log-odds space."
    },
    {
      name        = "shap_logit_map"
      type        = "JSON"
      mode        = "REQUIRED"
      description = "JSON map of feature names to SHAP logit contributions."
    },
    {
      name        = "top_adverse_reasons"
      type        = "JSON"
      mode        = "REQUIRED"
      description = "JSON array of top adverse reason codes and descriptions."
    },
    {
      name        = "feature_payload"
      type        = "JSON"
      mode        = "REQUIRED"
      description = "JSON object of governed input feature values used at inference."
    },
    {
      name        = "reason_rule_version"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Adverse action reason-code mapping version."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "ml_training_labels" {
  project                  = var.ml_ops_project_id
  dataset_id               = google_bigquery_dataset.ml_xai_audit.dataset_id
  table_id                 = "ml_training_labels"
  description              = "Governed point-in-time supervised training labels for ML.ENTITY_FEATURES_AT_TIME and MRM fairness validation."
  deletion_protection      = var.environment != "dev"
  require_partition_filter = true
  clustering               = ["entity_id", "approved_flag"]
  labels                   = var.labels

  time_partitioning {
    type  = "DAY"
    field = "label_timestamp"
  }

  schema = jsonencode([
    {
      name        = "application_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique underwriting or account evaluation identifier."
    },
    {
      name        = "entity_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Entity or customer identifier matching Silver ml_customer_features.entity_id."
    },
    {
      name        = "label_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Point-in-time outcome cutoff timestamp for ML.ENTITY_FEATURES_AT_TIME."
    },
    {
      name        = "approved_flag"
      type        = "INT64"
      mode        = "REQUIRED"
      description = "Supervised binary outcome label (1 = approved/performing, 0 = rejected/adverse)."
    },
    {
      name        = "demographic_group"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Optional protected cohort slice for MRM 80% disparate-impact fairness validation."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_project_service" "ml_ops_runtime_apis" {
  for_each = local.ml_ops_runtime_services

  project                    = var.ml_ops_project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service_identity" "ml_ops_runtime" {
  for_each = google_project_service.ml_ops_runtime_apis
  provider = google-beta

  project = var.ml_ops_project_id
  service = each.value.service
}

resource "google_kms_crypto_key_iam_member" "ml_ops_runtime_cmek" {
  for_each = local.use_cmek && var.manage_kms_iam ? google_project_service_identity.ml_ops_runtime : {}

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}

resource "google_project_service" "networkconnectivity_vpc_host" {
  count = var.enable_vertex_psc_policy && var.create_vertex_psc_policy && local.use_private_network && local.network_project_id != "" ? 1 : 0

  project                    = local.network_project_id
  service                    = "networkconnectivity.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_network_connectivity_service_connection_policy" "vertex_psc" {
  count = var.enable_vertex_psc_policy && var.create_vertex_psc_policy && local.use_private_network && local.network_project_id != "" ? 1 : 0

  project       = local.network_project_id
  location      = var.region
  name          = "${replace(lower(var.prefix), "_", "-")}-${var.environment}-vertex-psc"
  description   = "Automated PSC service connection policy for Agent Platform endpoints and Feature Online Store."
  service_class = "gcp-vertexai"
  network       = local.effective_vpc_id
  labels        = var.labels

  psc_config {
    subnetworks = [local.effective_subnet_id]
  }

  depends_on = [google_project_service.networkconnectivity_vpc_host]
}

resource "google_dataplex_datascan" "xai_audit" {
  count = var.enable_xai_quality_scan ? 1 : 0

  project      = var.ml_ops_project_id
  location     = var.region
  data_scan_id = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-ml-xai-audit-dq"), 0, 63), "-")
  display_name = "${var.prefix} ml_xai_audit_ledger quality"
  description  = "Knowledge Catalog Auto data quality scan enforcing SHAP additivity and provenance digests."
  labels       = var.labels

  data {
    resource = "//bigquery.googleapis.com/projects/${var.ml_ops_project_id}/datasets/${google_bigquery_dataset.ml_xai_audit.dataset_id}/tables/${google_bigquery_table.ml_xai_audit_ledger.table_id}"
  }

  execution_spec {
    trigger {
      dynamic "on_demand" {
        for_each = local.trimmed_xai_cron == "" ? [1] : []
        content {}
      }

      dynamic "schedule" {
        for_each = local.trimmed_xai_cron != "" ? [local.trimmed_xai_cron] : []
        content {
          cron = schedule.value
        }
      }
    }
  }

  data_quality_spec {
    sampling_percent = 100
    row_filter       = "DATE(decision_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)"

    rules {
      name        = "shap-additivity-invariant"
      description = "Verify base_logit plus shap_sum_logit matches raw_margin within tolerance."
      dimension   = "CONSISTENCY"
      row_condition_expectation {
        sql_expression = "ABS((base_logit + shap_sum_logit) - raw_margin) <= ${local.shap_tolerance_string} * GREATEST(1.0, ABS(raw_margin))"
      }
    }

    rules {
      name        = "container-image-digest-not-null"
      description = "Ensure container_image_digest is present on every audit row."
      column      = "container_image_digest"
      dimension   = "COMPLETENESS"
      non_null_expectation {}
    }

    rules {
      name        = "model-artifact-sha256-not-null"
      description = "Ensure model_artifact_sha256 is present on every audit row."
      column      = "model_artifact_sha256"
      dimension   = "COMPLETENESS"
      non_null_expectation {}
    }
  }
}
