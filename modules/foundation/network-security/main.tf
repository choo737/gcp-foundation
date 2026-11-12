locals {
  clean_access_policy_id = replace(var.access_policy_id, "accessPolicies/", "")

  vpc_sc_restricted_services = [
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "storage.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",
    "dataform.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
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

resource "google_compute_network" "this" {
  count = var.enable_vpc ? 1 : 0

  project                 = var.project_id
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
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

resource "google_access_context_manager_service_perimeter" "perimeter" {
  count = var.enable_vpc_sc && local.clean_access_policy_id != "" ? 1 : 0

  parent                    = "accessPolicies/${local.clean_access_policy_id}"
  name                      = "accessPolicies/${local.clean_access_policy_id}/servicePerimeters/${replace(var.prefix, "-", "_")}_data_perimeter"
  title                     = "${var.prefix}-data-perimeter"
  perimeter_type            = "PERIMETER_TYPE_REGULAR"
  use_explicit_dry_run_spec = !var.enforce_vpc_sc

  dynamic "spec" {
    for_each = !var.enforce_vpc_sc ? [1] : []
    content {
      resources           = [for num in var.perimeter_project_numbers : "projects/${num}"]
      restricted_services = local.vpc_sc_restricted_services
    }
  }

  dynamic "status" {
    for_each = var.enforce_vpc_sc ? [1] : []
    content {
      resources           = [for num in var.perimeter_project_numbers : "projects/${num}"]
      restricted_services = local.vpc_sc_restricted_services
    }
  }
}
