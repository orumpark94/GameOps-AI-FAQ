output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller Pod Identity."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "chatbot_api_role_arn" {
  description = "IAM role ARN for chatbot-api Pod Identity."
  value       = aws_iam_role.chatbot_api.arn
}
