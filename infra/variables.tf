variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "northeurope"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "azure-fullstack-app"
}
