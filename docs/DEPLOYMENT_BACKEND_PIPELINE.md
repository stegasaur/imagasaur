# Backend CI/CD Pipeline (ECS)

This document describes how the **Imagasaur** backend is built and deployed to AWS using **CodePipeline**, **ECR**, and **ECS Fargate**.

## High-level Flow

1. **Source** – A push to the `main` branch of [`stegasaur/imagasaur`](https://github.com/stegasaur/imagasaur) triggers the pipeline.
2. **Build** – The “ECRBuildAndPublish” action builds the Docker image from `backend/`, pushes it to ECR, and produces an `imagedefinitions.json` artifact.
3. **Deploy** – The ECS deploy action updates the Fargate service with the new image.

## Key AWS Resources

| Resource | Purpose |
|----------|---------|
| ECR repository | Stores backend Docker images |
| ECS Cluster & Service | Runs the backend Flask container on Fargate |
| CodePipeline | Orchestrates source, build and deploy stages |
| IAM Roles | Fine-grained permissions for Pipeline, ECS tasks, and execution |

## Managing the Pipeline

```bash
# Initialise & apply Terraform (from project root)
cd terraform
terraform init
terraform workspace new dev   # or select an existing workspace
terraform apply
```

After Terraform completes you can watch the pipeline in the AWS console under CodePipeline. The first run will build the image and deploy the backend.

## Useful Links

* [AWS CodePipeline console](https://console.aws.amazon.com/codepipeline)
* [AWS ECS console](https://console.aws.amazon.com/ecs)
* [AWS ECR console](https://console.aws.amazon.com/ecr)