# Service Account for MIG instances
resource "google_service_account" "webapp_sa" {
  account_id   = "webapp-auto-healing-sa"
  display_name = "Service Account for Auto-Healing MIG"
  description  = "Custom service account for auto-healing webapp instances"
}

# IAM: Logging
resource "google_project_iam_member" "webapp_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.webapp_sa.email}"
}

# IAM: Monitoring
resource "google_project_iam_member" "webapp_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.webapp_sa.email}"
}

# Health Check
resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = var.health_check_interval
  timeout_sec         = var.health_check_timeout
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = var.app_port
    request_path = var.health_check_path
  }

  log_config {
    enable = true
  }
}

# Firewall: Allow health checks from Google Cloud
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check-autohealing"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["webapp-auto-healing"]
  description = "Allow health checks from Google Cloud health checkers"
}

# Firewall: Allow HTTP from load balancer
resource "google_compute_firewall" "allow_lb_to_instances" {
  name    = "allow-lb-to-instances-autohealing"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["webapp-auto-healing"]
  description = "Allow traffic from load balancer to instances"
}

# Instance Template
resource "google_compute_instance_template" "webapp" {
  name_prefix  = "webapp-template-"
  machine_type = var.machine_type
  region       = var.region

  tags   = ["webapp-auto-healing", "http-server"]
  labels = var.labels

  disk {
    source_image = "${var.image_project}/${var.image_family}"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    network = "default"
    
    access_config {
      # Ephemeral external IP
    }
  }

  service_account {
    email  = google_service_account.webapp_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/../scripts/startup.sh")

  metadata = {
    enable-oslogin = "FALSE"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_service_account.webapp_sa,
    google_project_iam_member.webapp_logging,
    google_project_iam_member.webapp_monitoring
  ]
}

# Managed Instance Group with Auto-Healing
resource "google_compute_instance_group_manager" "webapp" {
  name               = "webapp-mig"
  base_instance_name = "webapp"
  zone               = var.zone
  target_size        = var.min_replicas

  version {
    instance_template = google_compute_instance_template.webapp.id
  }

  named_port {
    name = "http"
    port = var.app_port
  }

  # Auto-Healing Policy
  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = var.initial_delay_sec
  }

  update_policy {
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 2
    max_unavailable_fixed        = 1
    replacement_method           = "SUBSTITUTE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Autoscaler
resource "google_compute_autoscaler" "webapp" {
  name   = "webapp-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.webapp.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }

    scale_in_control {
      max_scaled_in_replicas {
        fixed = 1
      }
      time_window_sec = 300
    }
  }
}

