variable "name_prefix" {
  description = "Name prefix for knowledge base resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "document_prefix" {
  description = "S3 prefix containing the knowledge base source documents."
  type        = string
  default     = "dev/"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimensions" {
  description = "Embedding vector dimensions."
  type        = number
  default     = 1024
}

variable "chunk_max_tokens" {
  description = "Maximum tokens per fixed-size chunk."
  type        = number
  default     = 500
}

variable "chunk_overlap_percentage" {
  description = "Overlap percentage between fixed-size chunks."
  type        = number
  default     = 20
}
