# Backend Service
resource "google_compute_backend_service" "webapp" {
  name                  = "webapp-backend-service1"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  health_checks         = [google_compute_health_check.autohealing.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group           = google_compute_instance_group_manager.webapp.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map
resource "google_compute_url_map" "webapp" {
  name            = "webapp-url-map"
  default_service = google_compute_backend_service.webapp.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "webapp" {
  name    = "webapp-http-proxy"
  url_map = google_compute_url_map.webapp.id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "webapp" {
  name                  = "webapp-forwarding-rule"
  target                = google_compute_target_http_proxy.webapp.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
}

# Firewall: Allow HTTP from internet
resource "google_compute_firewall" "allow_http_from_internet" {
  name    = "allow-http-from-internet-autohealing"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
  description   = "Allow HTTP from internet to load balancer"
}
