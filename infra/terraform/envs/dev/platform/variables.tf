variable "namespace" {
  description = "Kubernetes namespace for the chatbot workloads."
  type        = string
  default     = "gameops-chatbot-dev"
}

variable "initial_image_tag" {
  description = "Initial ECR image tag. GitHub Actions can update Deployment images later."
  type        = string
  default     = "latest"
}

variable "web_replicas" {
  description = "chatbot-web replica count."
  type        = number
  default     = 2
}

variable "api_replicas" {
  description = "chatbot-api replica count."
  type        = number
  default     = 2
}

variable "bedrock_retrieval_score_threshold" {
  description = "Minimum Knowledge Base retrieval score required before generating an answer."
  type        = number
  default     = 0.6

  validation {
    condition = (
      var.bedrock_retrieval_score_threshold >= 0 &&
      var.bedrock_retrieval_score_threshold <= 1
    )
    error_message = "bedrock_retrieval_score_threshold must be between 0 and 1."
  }
}

variable "customer_support_email" {
  description = "Customer support email shown when no relevant FAQ is found."
  type        = string
  default     = "sjpark@hanbitsoft.com"
}

variable "host_name" {
  description = "Optional DNS host name used by the ALB Ingress rule."
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN. Null creates an HTTP listener for initial testing."
  type        = string
  default     = null
}

variable "alb_controller_chart_version" {
  description = "Optional AWS Load Balancer Controller Helm chart version. Null installs the repository default."
  type        = string
  default     = null
}
