/**
 * Terraform variables
 */

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gcloud-automation"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "G-Cloud Automation"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

# App Service
variable "app_service_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "B2"  # Basic tier, 2 cores, 3.5GB RAM
}

variable "backend_docker_image" {
  description = "Docker image for backend"
  type        = string
  default     = "gcloud-automation-backend"
}

variable "backend_docker_tag" {
  description = "Docker image tag for backend"
  type        = string
  default     = "latest"
}

variable "frontend_docker_image" {
  description = "Docker image for frontend"
  type        = string
  default     = "gcloud-automation-frontend"
}

variable "frontend_docker_tag" {
  description = "Docker image tag for frontend"
  type        = string
  default     = "latest"
}

variable "docker_registry_url" {
  description = "Docker registry URL"
  type        = string
  default     = "https://index.docker.io"
}

# Database
variable "db_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "gcloadmin"
  sensitive   = true
}

variable "db_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "postgres_sku" {
  description = "PostgreSQL SKU"
  type        = string
  default     = "B_Standard_B1ms"  # 1 vCore, 2GB RAM
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768  # 32GB
}

# Redis
variable "redis_capacity" {
  description = "Redis cache capacity"
  type        = number
  default     = 0  # Basic tier
}

variable "redis_family" {
  description = "Redis family"
  type        = string
  default     = "C"  # Basic/Standard
}

variable "redis_sku" {
  description = "Redis SKU"
  type        = string
  default     = "Basic"
}

# Storage
variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"  # Locally Redundant Storage
}

# Application
variable "app_secret_key" {
  description = "Application secret key"
  type        = string
  sensitive   = true
}

