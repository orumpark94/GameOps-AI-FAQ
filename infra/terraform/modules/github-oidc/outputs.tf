output "role_arn" {
  description = "IAM role ARN assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = local.github_oidc_provider_arn
}
