# Terraform

GameOps AI FAQ의 AWS Infrastructure와 EKS Platform을 서로 다른 Terraform State로 관리한다.

## Directory Structure

```text
infra/terraform/
├─ modules/
│  ├─ vpc/
│  ├─ ecr/
│  ├─ eks/
│  ├─ knowledge-base/
│  └─ workload-iam/
│
└─ envs/dev/
   ├─ infrastructure/
   │  ├─ VPC, Subnet, IGW, NAT Gateway
   │  ├─ ECR
   │  ├─ EKS, Managed Node Group, Add-ons
   │  ├─ S3 FAQ Bucket
   │  ├─ S3 Vectors
   │  ├─ Bedrock Knowledge Base
   │  └─ Workload IAM Roles
   │
   └─ platform/
      ├─ AWS Load Balancer Controller
      ├─ EKS Pod Identity Associations
      ├─ chatbot-web/api Deployments
      ├─ ClusterIP Services
      ├─ ALB Ingress
      ├─ NetworkPolicy
      └─ PodDisruptionBudget
```

Infrastructure와 Platform을 분리한 이유는 EKS 생성 전에 Kubernetes/Helm Provider가 EKS API에 접속하는 문제를 피하기 위해서다.

Platform은 Infrastructure의 로컬 State Output을 `terraform_remote_state`로 읽는다.

## Before Apply

1. AWS CLI 로그인 상태를 확인한다.
2. `eks_public_access_cidrs`를 현재 PC의 Public IPv4 `/32`로 제한한다.
3. Bedrock Nova Micro APAC Inference Profile이 활성 상태인지 확인한다.
4. FAQ 문서는 Infrastructure 생성 후 S3에 업로드한다.
5. ECR에 초기 `latest` 이미지가 없으면 Pod는 `ImagePullBackOff` 상태가 될 수 있다.

## Infrastructure

```powershell
cd infra\terraform\envs\dev\infrastructure
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init
terraform fmt -recursive ..\..\..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

EKS 접속 확인:

```powershell
aws eks update-kubeconfig `
  --region ap-northeast-2 `
  --name gameops-ai-faq-dev

kubectl get nodes
kubectl get pods -A
```

FAQ 문서 업로드:

```powershell
$bucket = terraform output -raw knowledge_base_document_bucket
aws s3 sync ..\..\..\..\..\knowledge-base "s3://$bucket/dev/" --delete
```

문서 업로드만으로 Ingestion Job이 자동 실행되는 것은 아니다. 최초 검증에서는 AWS Console 또는 AWS CLI로 Data Source Sync를 실행한다.

## Platform

Infrastructure Apply와 EKS Node Ready 확인 후 실행한다.

```powershell
cd ..\platform
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

확인:

```powershell
kubectl get pods -n gameops-chatbot-dev
kubectl get ingress -n gameops-chatbot-dev
terraform output load_balancer_hostname
```

## Destroy

삭제는 반드시 Platform부터 수행한다. Ingress를 먼저 삭제해야 AWS Load Balancer Controller가 ALB와 Target Group을 정리할 수 있다.

```powershell
cd infra\terraform\envs\dev\platform
terraform destroy

cd ..\infrastructure
terraform destroy
```

## State

현재는 로컬 PC에서만 Terraform을 실행하므로 Local State를 사용한다.

```text
envs/dev/infrastructure/terraform.tfstate
envs/dev/platform/terraform.tfstate
```

State 파일은 Git에 Commit하지 않는다. State를 잃어버리면 `terraform destroy`로 리소스를 추적하기 어려우므로 실습 중에는 파일을 별도로 안전하게 백업한다.

## Cost

- NAT Gateway 1개
- EKS Control Plane 1개
- `t3.medium` Node 2개
- Internet-facing ALB 1개
- Public IPv4
- Bedrock/S3 Vectors 사용량

실습을 마친 후 즉시 Platform과 Infrastructure를 순서대로 삭제한다.
