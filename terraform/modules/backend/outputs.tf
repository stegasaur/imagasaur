output "ecr_repository_name" {
  description = "Name of the ECR repository for backend images."
  value       = aws_ecr_repository.backend.name
}

output "ecr_repository_arn" {
  description = "ARN of the backend ECR repository."
  value       = aws_ecr_repository.backend.arn
}

output "ecr_repository_url" {
  description = "Repository URI for backend images."
  value       = aws_ecr_repository.backend.repository_url
}

output "load_balancer_arn" {
  description = "ARN of the backend Application Load Balancer"
  value       = aws_lb.backend.arn
}

output "load_balancer_zone_id" {
  description = "Zone ID of the backend Application Load Balancer"
  value       = aws_lb.backend.zone_id
}

output "load_balancer_dns_name" {
  description = "DNS name of the backend Application Load Balancer"
  value       = aws_lb.backend.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster hosting the backend service."
  value       = aws_ecs_cluster.backend.name
}

output "ecs_service_name" {
  description = "Name of the ECS service for the backend."
  value       = aws_ecs_service.backend.name
}

output "container_name" {
  description = "Name of the container in the ECS task definition."
  value       = local.container_name
}
