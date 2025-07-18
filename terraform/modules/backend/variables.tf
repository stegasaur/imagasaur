variable "project_name" {
  description = "Name of the project."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "uploads_bucket" {
  description = "Name of the S3 bucket that stores original uploads."
  type        = string
}

variable "processed_bucket" {
  description = "Name of the S3 bucket that stores processed images."
  type        = string
}

variable "container_port" {
  description = "Port that the backend container listens on."
  type        = number
  default     = 5000
}

variable "vpc_id" {
  description = "ID of the VPC where backend resources will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for Load Balancer."
  type        = list(string)
}