# SellPilot infrastructure - stub for Phase 0
# Real resources (RDS, S3, EC2, etc.) added in Phase 3

terraform {
  required_version = ">= 1.0"
}

variable "environment" {
  type    = string
  default = "development"
}

output "environment" {
  value = var.environment
}
