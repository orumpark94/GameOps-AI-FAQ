variable "name_prefix" {
  description = "Name prefix for workload IAM resources."
  type        = string
}

variable "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN used by chatbot-api."
  type        = string
}

variable "generation_model_resource_arns" {
  description = "Bedrock inference profile and underlying model ARNs used for generation."
  type        = list(string)
}
