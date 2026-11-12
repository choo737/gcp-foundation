locals {
  clean_access_policy_id         = replace(var.access_policy_id, "accessPolicies/", "")
  effective_network_project_num  = var.network_project_number != null ? trimspace(var.network_project_number) : ""
  effective_audit_project_num    = var.vpc_sc_audit_project_number != null ? trimspace(var.vpc_sc_audit_project_number) : ""
  effective_dr_region            = var.dr_region != null ? trimspace(var.dr_region) : ""
  create_dr_cmek                 = var.enable_cmek && local.effective_dr_region != "" && local.effective_dr_region != var.region
  initial_vpc_sc_project_numbers = distinct(compact(concat([local.effective_network_project_num], var.perimeter_project_numbers)))
  initial_vpc_sc_resources       = [for num in local.initial_vpc_sc_project_numbers : "projects/${num}"]

  vpc_sc_restricted_services = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudscheduler.googleapis.com",
    "datacatalog.googleapis.com",
    "dataform.googleapis.com",
    "dataplex.googleapis.com",
    "datastream.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "workflows.googleapis.com",
  ]

  psc_artifact_dns_zones = var.enable_vpc && var.enable_psc ? {
    pkg_dev = {
      zone_name = "${var.prefix}-pkg-dev-zone"
      dns_name  = "pkg.dev."
    }
    gcr_io = {
      zone_name = "${var.prefix}-gcr-io-zone"
      dns_name  = "gcr.io."
    }
  } : {}
}

resource "google_kms_key_ring" "this" {
  count = var.enable_cmek ? 1 : 0

  project  = var.project_id
  name     = "${var.prefix}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "this" {
  count = var.enable_cmek ? 1 : 0

  name                       = "${var.prefix}-cmek-key"
  key_ring                   = google_kms_key_ring.this[0].id
  purpose                    = "ENCRYPT_DECRYPT"
  rotation_period            = "7776000s"
  destroy_scheduled_duration = "2592000s"
  labels                     = var.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }
}

resource "google_kms_key_ring" "dr" {
  count = local.create_dr_cmek ? 1 : 0

  project  = var.project_id
  name     = "${var.prefix}-dr-keyring"
  location = local.effective_dr_region
}

resource "google_kms_crypto_key" "dr" {
  count = local.create_dr_cmek ? 1 : 0

  name                       = "${var.prefix}-dr-cmek-key"
  key_ring                   = google_kms_key_ring.dr[0].id
  purpose                    = "ENCRYPT_DECRYPT"
  rotation_period            = "7776000s"
  destroy_scheduled_duration = "2592000s"
  labels                     = var.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }
}

resource "google_compute_network" "this" {
  count = var.enable_vpc ? 1 : 0

  project                 = var.project_id
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_shared_vpc_host_project" "this" {
  count = var.enable_vpc && var.enable_shared_vpc_host ? 1 : 0

  project    = var.project_id
  depends_on = [google_compute_network.this]
}

resource "google_compute_subnetwork" "this" {
  count = var.enable_vpc ? 1 : 0

  project                  = var.project_id
  name                     = "${var.prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.this[0].id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.enable_vpc_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = var.vpc_flow_logs_sampling
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_subnetwork" "datastream_nat" {
  count = var.enable_vpc && var.enable_datastream_psc_attachment ? 1 : 0

  project                  = var.project_id
  name                     = "${var.prefix}-${var.environment}-datastream-nat"
  region                   = var.region
  network                  = google_compute_network.this[0].id
  ip_cidr_range            = var.datastream_nat_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_network_attachment" "datastream" {
  count = var.enable_vpc && var.enable_datastream_psc_attachment ? 1 : 0

  project               = var.project_id
  region                = var.region
  name                  = "${var.prefix}-${var.environment}-datastream-psc"
  description           = "Private Service Connect network attachment for Datastream CDC."
  connection_preference = length(var.datastream_producer_accept_lists) > 0 ? "ACCEPT_MANUAL" : "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.datastream_nat[0].self_link]
  producer_accept_lists = length(var.datastream_producer_accept_lists) > 0 ? var.datastream_producer_accept_lists : null
}

resource "google_dns_policy" "logging" {
  count = var.enable_vpc && var.enable_dns_logging ? 1 : 0

  project        = var.project_id
  name           = "${var.prefix}-dns-logging"
  enable_logging = true
  description    = "Enable Cloud DNS query logging for the private VPC."

  networks {
    network_url = google_compute_network.this[0].id
  }
}

resource "google_compute_global_address" "psc" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project      = var.project_id
  name         = "${var.prefix}-psc-ip"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  address_type = "INTERNAL"
  network      = google_compute_network.this[0].id
  address      = var.psc_ip_address
  labels       = var.labels
}

resource "google_compute_global_forwarding_rule" "psc" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project               = var.project_id
  name                  = substr(lower(replace("${var.prefix}pscallapis", "-", "")), 0, 20)
  target                = var.enable_vpc_sc ? "vpc-sc" : "all-apis"
  network               = google_compute_network.this[0].id
  ip_address            = google_compute_global_address.psc[0].id
  load_balancing_scheme = ""
  labels                = var.labels
}

resource "google_dns_managed_zone" "googleapis" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project     = var.project_id
  name        = "${var.prefix}-googleapis-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS zone routing googleapis.com to the Private Service Connect endpoint."
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.this[0].id
    }
  }
}

resource "google_dns_record_set" "googleapis_a" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project      = var.project_id
  managed_zone = google_dns_managed_zone.googleapis[0].name
  name         = "googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc[0].address]
}

resource "google_dns_record_set" "googleapis_cname" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project      = var.project_id
  managed_zone = google_dns_managed_zone.googleapis[0].name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["googleapis.com."]
}

resource "google_dns_managed_zone" "psc_artifact" {
  for_each = local.psc_artifact_dns_zones

  project     = var.project_id
  name        = each.value.zone_name
  dns_name    = each.value.dns_name
  description = "Private DNS zone routing ${each.value.dns_name} to the Private Service Connect endpoint."
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.this[0].id
    }
  }
}

resource "google_dns_record_set" "psc_artifact_a" {
  for_each = local.psc_artifact_dns_zones

  project      = var.project_id
  managed_zone = google_dns_managed_zone.psc_artifact[each.key].name
  name         = each.value.dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc[0].address]
}

resource "google_dns_record_set" "psc_artifact_cname" {
  for_each = local.psc_artifact_dns_zones

  project      = var.project_id
  managed_zone = google_dns_managed_zone.psc_artifact[each.key].name
  name         = "*.${each.value.dns_name}"
  type         = "CNAME"
  ttl          = 300
  rrdatas      = [each.value.dns_name]
}

resource "google_compute_network_firewall_policy" "egress" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project     = var.project_id
  name        = "${var.prefix}-egress-policy"
  description = "Network firewall policy enforcing private PSC egress and default deny-all."
}

resource "google_compute_network_firewall_policy_association" "egress" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project           = var.project_id
  name              = "${var.prefix}-egress-policy-assoc"
  attachment_target = google_compute_network.this[0].id
  firewall_policy   = google_compute_network_firewall_policy.egress[0].name
}

resource "google_compute_network_firewall_policy_rule" "allow_psc_egress" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.egress[0].name
  rule_name       = "${var.prefix}-allow-psc-https"
  description     = "Allow HTTPS egress only to the Private Service Connect endpoint."
  direction       = "EGRESS"
  priority        = 1000
  action          = "allow"
  enable_logging  = true

  match {
    dest_ip_ranges = ["${google_compute_global_address.psc[0].address}/32"]

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["443"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "allow_private_db_egress" {
  count = var.enable_vpc && var.enable_psc && length(var.allowed_private_db_cidrs) > 0 ? 1 : 0

  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.egress[0].name
  rule_name       = "${var.prefix}-allow-private-db"
  description     = "Allow PostgreSQL and MySQL egress to authorized private source DB CIDRs."
  direction       = "EGRESS"
  priority        = 1100
  action          = "allow"
  enable_logging  = true

  match {
    dest_ip_ranges = var.allowed_private_db_cidrs

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["5432", "3306"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "deny_all_egress" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.egress[0].name
  rule_name       = "${var.prefix}-deny-all-egress"
  description     = "Default deny-all egress rule."
  direction       = "EGRESS"
  priority        = 65530
  action          = "deny"
  enable_logging  = true

  match {
    dest_ip_ranges = ["0.0.0.0/0"]

    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_access_context_manager_access_level" "trusted" {
  count = var.enable_vpc_sc && local.clean_access_policy_id != "" && length(var.vpc_sc_access_level_members) > 0 ? 1 : 0

  parent = "accessPolicies/${local.clean_access_policy_id}"
  name   = "accessPolicies/${local.clean_access_policy_id}/accessLevels/${replace(var.prefix, "-", "_")}_${var.environment}_trusted"
  title  = "${var.prefix}-${var.environment}-trusted"

  basic {
    conditions {
      members = var.vpc_sc_access_level_members
    }
  }
}

resource "google_access_context_manager_service_perimeter" "perimeter" {
  count = var.enable_vpc_sc && local.clean_access_policy_id != "" ? 1 : 0

  parent                    = "accessPolicies/${local.clean_access_policy_id}"
  name                      = "accessPolicies/${local.clean_access_policy_id}/servicePerimeters/${replace(var.prefix, "-", "_")}_${var.environment}_data_perimeter"
  title                     = "${var.prefix}-${var.environment}-data-perimeter"
  perimeter_type            = "PERIMETER_TYPE_REGULAR"
  use_explicit_dry_run_spec = !var.enforce_vpc_sc

  dynamic "spec" {
    for_each = !var.enforce_vpc_sc ? [1] : []
    content {
      resources           = local.initial_vpc_sc_resources
      restricted_services = local.vpc_sc_restricted_services
      access_levels       = length(google_access_context_manager_access_level.trusted) > 0 ? [google_access_context_manager_access_level.trusted[0].name] : []

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      dynamic "ingress_policies" {
        for_each = length(var.vpc_sc_ingress_principals) > 0 ? [1] : []
        content {
          title = "${var.prefix}-${var.environment}-trusted-ingress"
          ingress_from {
            identities = var.vpc_sc_ingress_principals
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }

      dynamic "egress_policies" {
        for_each = local.effective_audit_project_num != "" ? [1] : []
        content {
          title = "${var.prefix}-${var.environment}-audit-egress"
          egress_from {
            identity_type = "ANY_IDENTITY"
          }
          egress_to {
            resources = ["projects/${local.effective_audit_project_num}"]
            operations {
              service_name = "logging.googleapis.com"
              method_selectors {
                method = "*"
              }
            }
            operations {
              service_name = "bigquery.googleapis.com"
              method_selectors {
                method = "*"
              }
            }
          }
        }
      }
    }
  }

  dynamic "status" {
    for_each = var.enforce_vpc_sc ? [1] : []
    content {
      resources           = local.initial_vpc_sc_resources
      restricted_services = local.vpc_sc_restricted_services
      access_levels       = length(google_access_context_manager_access_level.trusted) > 0 ? [google_access_context_manager_access_level.trusted[0].name] : []

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      dynamic "ingress_policies" {
        for_each = length(var.vpc_sc_ingress_principals) > 0 ? [1] : []
        content {
          title = "${var.prefix}-${var.environment}-trusted-ingress"
          ingress_from {
            identities = var.vpc_sc_ingress_principals
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }

      dynamic "egress_policies" {
        for_each = local.effective_audit_project_num != "" ? [1] : []
        content {
          title = "${var.prefix}-${var.environment}-audit-egress"
          egress_from {
            identity_type = "ANY_IDENTITY"
          }
          egress_to {
            resources = ["projects/${local.effective_audit_project_num}"]
            operations {
              service_name = "logging.googleapis.com"
              method_selectors {
                method = "*"
              }
            }
            operations {
              service_name = "bigquery.googleapis.com"
              method_selectors {
                method = "*"
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      status[0].resources,
      spec[0].resources,
      status[0].ingress_policies,
      spec[0].ingress_policies,
    ]
  }
}
