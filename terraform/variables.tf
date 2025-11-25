variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for MIG"
  type        = string
  default     = "us-central1-a"
}

variable "image_family" {
  description = "OS image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project containing the OS image"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-micro"
}

variable "min_replicas" {
  description = "Minimum number of instances"
  type        = number
  default     = 3
}

variable "max_replicas" {
  description = "Maximum number of instances with autoscaling"
  type        = number
  default     = 5
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/api/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successes for healthy status"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failures for unhealthy status"
  type        = number
  default     = 2
}

variable "initial_delay_sec" {
  description = "Initial delay before health checks start (seconds)"
  type        = number
  default     = 300
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "gcp-learning"
    environment = "dev"
    managed_by  = "terraform"
    deployment  = "auto-healing"
  }
}

