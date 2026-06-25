output "document_bucket_name" {
  description = "S3 bucket containing knowledge base source documents."
  value       = aws_s3_bucket.documents.bucket
}

output "document_bucket_arn" {
  description = "ARN of the S3 bucket containing knowledge base source documents."
  value       = aws_s3_bucket.documents.arn
}

output "document_prefix" {
  description = "S3 document prefix used by the Bedrock data source."
  value       = var.document_prefix
}

output "vector_bucket_arn" {
  description = "S3 Vectors bucket ARN."
  value       = aws_s3vectors_vector_bucket.this.vector_bucket_arn
}

output "vector_index_arn" {
  description = "S3 Vectors index ARN."
  value       = aws_s3vectors_index.this.index_arn
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID."
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN."
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "data_source_id" {
  description = "Bedrock Knowledge Base data source ID."
  value       = aws_bedrockagent_data_source.this.data_source_id
}

output "embedding_model_arn" {
  description = "Embedding model ARN."
  value       = local.embedding_model_arn
}
