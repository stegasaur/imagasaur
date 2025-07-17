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

output "ecs_cluster_name" {
  description = "Name of the ECS cluster hosting the backend service."
  value       = aws_ecs_cluster.backend.name
}

output "ecs_service_name" {
  description = "Name of the ECS service for the backend."
  value       = aws_ecs_service.backend.name
}