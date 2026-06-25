# Terraform

AWS Seoul region dev infrastructure for GameOps AI FAQ.

## Current Scope

- VPC
- Public subnets for ALB
- Private subnets for future EKS nodes
- Internet Gateway
- NAT Gateway
- ECR repositories for `chatbot-web` and `chatbot-api`

EKS, ALB Controller, GitHub OIDC, Bedrock, S3, and S3 Vectors are intentionally not included yet.

## Dev Commands

```bash
cd infra/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan
```

Apply only after reviewing the plan.

```bash
terraform apply
```

## Cost Note

The dev VPC uses `single_nat_gateway = true` by default to reduce cost. This is acceptable for a toy dev environment, but it is not highly available. Use one NAT Gateway per AZ later by setting:

```hcl
single_nat_gateway = false
```
