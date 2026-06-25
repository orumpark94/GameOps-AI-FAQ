output "namespace" {
  description = "Application Kubernetes namespace."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "load_balancer_hostname" {
  description = "ALB DNS hostname created for chatbot-web."
  value       = try(kubernetes_ingress_v1.web.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "web_image" {
  description = "Initial chatbot-web image reference."
  value       = "${local.web_repository_url}:${var.initial_image_tag}"
}

output "api_image" {
  description = "Initial chatbot-api image reference."
  value       = "${local.api_repository_url}:${var.initial_image_tag}"
}
