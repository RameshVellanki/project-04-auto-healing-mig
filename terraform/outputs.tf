# Load Balancer
output "lb_ip_address" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_forwarding_rule.webapp.ip_address
}

output "lb_url" {
  description = "URL to access the application"
  value       = "http://${google_compute_global_forwarding_rule.webapp.ip_address}"
}

# MIG Details
output "mig_name" {
  description = "Name of the managed instance group"
  value       = google_compute_instance_group_manager.webapp.name
}

output "mig_zone" {
  description = "Zone of the managed instance group"
  value       = var.zone
}

output "mig_size" {
  description = "Current target size of MIG"
  value       = var.min_replicas
}

# Health Check
output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.autohealing.name
}

output "health_check_interval" {
  description = "Health check interval in seconds"
  value       = var.health_check_interval
}

output "initial_delay" {
  description = "Initial delay before health checks start"
  value       = var.initial_delay_sec
}

# Service Account
output "service_account_email" {
  description = "Service account email"
  value       = google_service_account.webapp_sa.email
}

# Test Commands
output "test_commands" {
  description = "Commands to test auto-healing"
  value = <<-EOT
    # Access the application
    curl http://${google_compute_global_forwarding_rule.webapp.ip_address}
    
    # Check health endpoint
    curl http://${google_compute_global_forwarding_rule.webapp.ip_address}/api/health
    
    # List MIG instances
    gcloud compute instance-groups managed list-instances ${google_compute_instance_group_manager.webapp.name} --zone=${var.zone}
    
    # Describe MIG (view auto-healing config)
    gcloud compute instance-groups managed describe ${google_compute_instance_group_manager.webapp.name} --zone=${var.zone}
    
    # Test auto-healing by stopping app on an instance:
    # 1. Get instance name:
    gcloud compute instances list --filter="name:webapp-"
    
    # 2. Stop the application (triggers auto-healing):
    gcloud compute ssh INSTANCE_NAME --zone=${var.zone} --command="sudo systemctl stop webapp"
    
    # 3. Watch auto-healing in action:
    watch -n 5 'gcloud compute instance-groups managed list-instances ${google_compute_instance_group_manager.webapp.name} --zone=${var.zone}'
    
    # View recent operations (recreations):
    gcloud compute operations list --filter="operationType:compute.instances.repair" --limit=10
    
    # Check backend health:
    gcloud compute backend-services get-health ${google_compute_backend_service.webapp.name} --global
  EOT
}

# Monitoring Commands
output "monitoring_commands" {
  description = "Commands for monitoring auto-healing"
  value = <<-EOT
    # View auto-healing events in Cloud Logging:
    gcloud logging read 'resource.type="gce_instance" AND protoPayload.methodName="v1.compute.instances.repair"' --limit=20
    
    # View health check failures:
    gcloud logging read 'resource.type="gce_instance" AND jsonPayload.message=~"health check"' --limit=20
    
    # Monitor MIG status:
    gcloud compute instance-groups managed describe ${google_compute_instance_group_manager.webapp.name} --zone=${var.zone}
  EOT
}
