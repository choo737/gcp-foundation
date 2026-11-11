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

resource "google_compute_firewall" "psc_egress" {
  count = var.enable_vpc && var.enable_psc ? 1 : 0

  project            = var.project_id
  name               = "${var.prefix}-allow-psc-egress"
  network            = google_compute_network.this[0].id
  direction          = "EGRESS"
  priority           = 1000
  destination_ranges = ["${google_compute_global_address.psc[0].address}/32"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
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
