output "pipeline_url" {
  description = "Console URL for the Image Processor CodePipeline"
  value       = aws_codepipeline.pipeline.id # placeholder, will update after pipeline resource is added.
}