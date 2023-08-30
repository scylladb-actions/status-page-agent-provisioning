terraform {
  required_providers {
    scylladbcloud = {
      source = "registry.terraform.io/scylladb/scylladbcloud"
    }
  }
}

variable "token" {
  type = string
}

variable "api_endpoint" {
  type = string
  default = "https://cloud.scylladb.com/api"
}

provider "scylladbcloud" {
  token = var.token
  endpoint = var.api_endpoint
}

