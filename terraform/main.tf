terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configuration for storing state in GCS
  backend "gcs" {
    bucket = "tftbk"
    prefix = "project-04/terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
