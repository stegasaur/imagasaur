output "pipeline_url" {
  description = "Console URL for the Image Processor CodePipeline"
  value       = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.pipeline.name}/view?region=${data.aws_region.current.name}"
}

data "aws_region" "current" {}