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
│  ├─ workload-iam/
│  └─ github-oidc/
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
   │  ├─ SSM Deployment Parameters
   │  └─ GitHub Actions OIDC Role
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
6. `github_repository`과 `github_deployment_branch`가 실제 배포 저장소 및 브랜치와 일치하는지 확인한다.
7. AWS Account에 `token.actions.githubusercontent.com` OIDC Provider가 이미 있다면
   `github_oidc_provider_arn`에 기존 Provider ARN을 입력한다.

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

## Deployment Parameters

Infrastructure Apply는 GitHub Actions가 사용할 현재 AWS 리소스 값을 SSM Parameter Store에 기록한다.

```text
/gameops-ai-faq/dev/aws-region
/gameops-ai-faq/dev/eks/cluster-name
/gameops-ai-faq/dev/ecr/web-repository-url
/gameops-ai-faq/dev/ecr/api-repository-url
/gameops-ai-faq/dev/kb/document-bucket
/gameops-ai-faq/dev/kb/document-prefix
/gameops-ai-faq/dev/kb/knowledge-base-id
/gameops-ai-faq/dev/kb/data-source-id
```

Infrastructure를 Destroy하고 다시 Apply하면 동적으로 변경된 Knowledge Base ID, Data Source ID,
S3 Bucket, ECR URL이 Parameter Store에 새 값으로 기록된다.

확인:

```powershell
aws ssm get-parameters-by-path `
  --path "/gameops-ai-faq/dev" `
  --recursive `
  --with-decryption
```

GitHub Actions Role ARN 확인:

```powershell
terraform output -raw github_actions_role_arn
```

이 ARN은 GitHub Repository의 `Settings > Secrets and variables > Actions > Variables`에서
`AWS_ROLE_ARN`이라는 Repository Variable로 한 번 등록한다. 동일 AWS Account에서 Terraform이
같은 이름의 Role을 재생성하면 ARN은 유지된다.

GitHub Actions는 다음 권한만 가진다.

- SSM 배포 Parameter 읽기
- 두 ECR Repository에 Image Push
- Knowledge Base 문서 Prefix에 S3 Sync
- Bedrock Knowledge Base Ingestion Job 실행 및 조회

EKS 접근 권한은 포함하지 않는다. EKS Deployment 변경은 로컬 PC의 `kubectl` 배포 스크립트가
담당한다.

## GitHub Actions

`main` 브랜치의 `apps/` 변경은 Application Image Workflow를 실행한다.

```text
.github/workflows/app-images.yml
```

이 Workflow는 다음 작업만 수행한다.

```text
GitHub OIDC
→ AWS IAM Role Assume
→ SSM에서 현재 ECR URL 조회
→ Linux Docker Image Build
→ Commit SHA 및 latest Tag로 ECR Push
```

수동 실행에서는 `all`, `chatbot-api`, `chatbot-web` 중 하나를 선택할 수 있다.

`main` 브랜치의 `knowledge-base/` 변경은 Knowledge Base Sync Workflow를 실행한다.

```text
.github/workflows/knowledge-base-sync.yml
```

```text
Metadata JSON 검사
→ SSM에서 현재 S3/Knowledge Base 값 조회
→ S3 dev/ Prefix 동기화
→ Bedrock Ingestion Job 실행
→ COMPLETE 상태까지 대기
```

GitHub Actions IAM Role은 `orumpark94/GameOps-AI-FAQ` 저장소의 `main` 브랜치 OIDC Subject만
신뢰한다. 다른 저장소 또는 브랜치는 Role을 Assume할 수 없다.

## Local Application Deployment

GitHub Actions에서 ECR Push가 완료되면 Workflow Summary의 Commit SHA를 사용한다.

```powershell
.\scripts\deploy-app.ps1 `
  -Service all `
  -ImageTag <GIT_COMMIT_SHA>
```

서비스 하나만 배포할 수도 있다.

```powershell
.\scripts\deploy-app.ps1 `
  -Service chatbot-api `
  -ImageTag <GIT_COMMIT_SHA>
```

스크립트 처리 순서:

```text
로컬 Terraform Output에서 Region, Cluster, ECR URL 조회
→ AWS 로그인 확인
→ kubeconfig 갱신
→ ECR Image Tag 존재 확인
→ kubectl set image
→ kubectl rollout status
```

`all`은 chatbot-api를 먼저 배포한 뒤 chatbot-web을 배포한다.

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
