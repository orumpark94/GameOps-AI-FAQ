# Terraform 운영 가이드

GameOps AI FAQ의 AWS 기반 인프라와 EKS 내부 플랫폼을 관리합니다. `dev` 환경은 두 개의 Local State를 사용합니다.

## 구성 경계

| Root Module | Provider | 관리 대상 |
|---|---|---|
| `envs/dev/infrastructure` | AWS | VPC, ECR, EKS, IAM, S3, S3 Vectors, Bedrock Knowledge Base, SSM, GitHub OIDC |
| `envs/dev/platform` | AWS, Kubernetes, Helm | Pod Identity, ALB Controller, Namespace, Deployment, Service, Ingress, NetworkPolicy, PDB |

Platform은 `terraform_remote_state`로 Infrastructure Output을 읽습니다. 생성은 Infrastructure → Platform, 삭제는 Platform → Infrastructure 순서입니다.

## 사전 조건

- Terraform `>= 1.7.0`, AWS CLI, kubectl, Docker
- 대상 리전 `ap-northeast-2`의 AWS 인증과 리소스 생성 권한
- Nova Micro APAC Inference Profile 및 Titan Text Embeddings V2 사용 가능 상태
- `eks_public_access_cidrs`를 작업자 Public IPv4 `/32`로 제한
- `github_repository`, `github_deployment_branch`를 실제 배포 대상과 일치시킴

`terraform.tfvars`와 State는 Commit하지 않습니다. AWS Access Key도 저장소 파일로 관리하지 않아야 합니다.

## 1. Infrastructure 배포

```powershell
cd infra\terraform\envs\dev\infrastructure
terraform init
terraform fmt -recursive ..\..\..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name gameops-ai-faq-dev
kubectl get nodes
kubectl get pods -A
```

Infrastructure는 GitHub Actions가 현재 리소스를 찾도록 `/gameops-ai-faq/dev` 아래에 ECR URL, S3 위치, Knowledge Base ID 등을 SSM Parameter로 기록합니다. GitHub에는 아래 결과를 Repository Variable `AWS_ROLE_ARN`으로 등록합니다.

```powershell
terraform output -raw github_actions_role_arn
```

## 2. 초기 이미지와 FAQ 문서

Deployment의 초기 태그는 `latest`입니다. ECR에 이미지가 없으면 `ImagePullBackOff`가 발생하므로 Platform Apply 전에 `app-images.yml`을 실행하거나 직접 Push합니다.

게임문의, 결제문의, 계정문의, 해킹/신고 FAQ를 수동 업로드할 경우:

```powershell
$bucket = terraform output -raw knowledge_base_document_bucket
aws s3 sync ..\..\..\..\..\knowledge-base "s3://$bucket/dev/" --delete
```

S3 업로드만으로 Ingestion Job이 시작되지는 않습니다. `knowledge-base-sync.yml` 또는 AWS CLI/Console에서 Data Source Sync를 시작해야 합니다.

## 3. Platform 배포

```powershell
cd ..\platform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

kubectl get pods -n gameops-chatbot-dev
kubectl get ingress -n gameops-chatbot-dev
terraform output load_balancer_hostname
```

`host_name`과 `acm_certificate_arn`이 `null`이면 HTTP 80으로 테스트합니다. 인증서 ARN이 있으면 HTTPS 443 Listener와 SSL Redirect를 사용합니다. DNS 레코드는 이 Terraform에서 생성하지 않습니다.

## 배포 책임 경계

`app-images.yml`은 OIDC로 AWS Role을 Assume하고 ECR에 Commit SHA와 `latest`를 Push합니다. 클러스터 배포는 로컬 스크립트가 담당합니다.

```powershell
.\scripts\deploy-app.ps1 -Service all -ImageTag <GIT_COMMIT_SHA>
```

Terraform은 Deployment 이미지 변경을 무시합니다. 이후 Platform Apply가 CI/CD에서 배포한 SHA 태그를 초기 태그로 되돌리지 않게 하는 의도적 경계입니다.

`knowledge-base-sync.yml`은 각 Markdown의 메타데이터 파일 존재 여부와 JSON 문법을 검사하고 S3를 동기화한 뒤 Ingestion 완료를 확인합니다. 메타데이터 카테고리 값의 의미적 유효성까지 검사하지는 않습니다. GitHub Role은 지정 저장소·브랜치만 신뢰하며 SSM 읽기, 두 ECR Push, 지정 S3 Prefix, Ingestion 권한만 가집니다. EKS 배포 권한은 없습니다.

## 삭제

```powershell
cd infra\terraform\envs\dev\platform
terraform destroy

cd ..\infrastructure
terraform destroy
```

Ingress를 먼저 제거해야 Controller가 ALB, Target Group, 관련 보안 그룹을 정리할 수 있습니다. 반대 순서는 VPC 삭제 실패나 잔여 리소스를 유발할 수 있습니다.

## 비용과 State

주요 상시 비용은 EKS Control Plane, `t3.medium` 노드 2대, NAT Gateway 1개, Internet-facing ALB와 Public IPv4입니다. Bedrock, S3, S3 Vectors는 사용량 기반입니다.

Local State는 개인 개발용 선택입니다. State 유실 시 리소스 추적과 삭제가 어렵습니다. 팀·운영 환경에서는 암호화, 버전 관리, 접근 통제, State Locking을 제공하는 Remote Backend로 전환해야 합니다.
