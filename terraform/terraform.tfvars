# Copy this file to terraform.tfvars and update with your values

project_id = "leafy-glyph-479507-m4"
region     = "us-central1"
zone       = "us-central1-a"

# Instance configuration
machine_type = "e2-micro"
min_replicas = 3
max_replicas = 5

# Health check configuration
app_port               = 8080
health_check_path      = "/api/health"
health_check_interval  = 10
health_check_timeout   = 5
healthy_threshold      = 2
unhealthy_threshold    = 2
initial_delay_sec      = 300

labels = {
  project     = "gcp-learning"
  environment = "dev"
  managed_by  = "terraform"
  deployment  = "auto-healing"
}
