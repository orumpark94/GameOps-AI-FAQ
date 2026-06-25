# GameOps AI FAQ Terraform 및 EKS 구성 설계

이 문서는 GameOps AI FAQ 프로젝트에서 Terraform으로 AWS Infrastructure와 EKS Platform을 어떻게 구성하고 연결했는지 설명한다.

단순한 파일 목록이 아니라 다음 내용을 이해하는 것이 목적이다.

- Terraform Module과 Root Module의 역할 차이
- Infrastructure와 Platform State를 분리한 이유
- Infrastructure Output을 Platform이 참조하는 방식
- VPC, ECR, EKS, IAM, Bedrock 리소스 간 의존성
- EKS 내부에서 `chatbot-web`과 `chatbot-api`를 분리한 방법
- Terraform과 GitHub Actions의 관리 경계
- 생성과 삭제 순서가 중요한 이유

---

## 1. 전체 아키텍처

외부 사용자의 요청 흐름은 다음과 같다.

```text
Internet
→ Internet Gateway
→ Internet-facing ALB
→ Kubernetes Ingress
→ chatbot-web ClusterIP Service
→ chatbot-web Pod
→ chatbot-api ClusterIP Service
→ chatbot-api Pod
→ Amazon Bedrock Knowledge Bases
→ S3 Vectors
```

FAQ 문서 수집 흐름은 다음과 같다.

```text
Git Repository의 knowledge-base 문서
→ S3 FAQ Document Bucket 업로드
→ Bedrock Data Source Sync
→ 문서 Parsing 및 Chunking
→ Titan Text Embeddings V2
→ S3 Vectors 저장
```

---

## 2. Terraform 디렉터리 구조

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
   │  ├─ main.tf
   │  ├─ providers.tf
   │  ├─ variables.tf
   │  ├─ outputs.tf
   │  └─ terraform.tfvars.example
   │
   └─ platform/
      ├─ main.tf
      ├─ providers.tf
      ├─ variables.tf
      ├─ applications.tf
      ├─ network.tf
      ├─ outputs.tf
      └─ terraform.tfvars.example
```

### 2.1 Module

`modules/`는 재사용 가능한 설계 부품이다.

```text
modules/vpc
= VPC를 어떤 AWS 리소스 조합으로 만들 것인가

modules/eks
= EKS Cluster와 Node Group을 어떻게 만들 것인가

modules/knowledge-base
= S3와 Bedrock Knowledge Base를 어떻게 연결할 것인가
```

Module 자체는 일반적으로 직접 실행하지 않는다.

### 2.2 Root Module

실제로 `terraform apply`를 실행하는 디렉터리가 Root Module이다.

```text
envs/dev/infrastructure
= dev 환경의 AWS 리소스 실행 단위

envs/dev/platform
= dev EKS 내부 리소스 실행 단위
```

Root Module은 Module에 실제 환경값을 전달한다.

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name       = var.eks_cluster_name
  private_subnet_ids = module.vpc.private_subnet_ids
}
```

---

## 3. Terraform State를 두 개로 분리한 이유

프로젝트는 다음 두 State를 사용한다.

```text
Infrastructure State
Platform State
```

### 3.1 Infrastructure State

AWS Provider가 관리하는 장기 인프라를 포함한다.

```text
VPC
Subnet
Route Table
Internet Gateway
NAT Gateway
ECR
EKS Cluster
Managed Node Group
EKS Add-ons
IAM Role과 Policy
S3 FAQ Bucket
S3 Vectors
Bedrock Knowledge Base
```

### 3.2 Platform State

이미 생성된 EKS Kubernetes API에 접속해서 관리하는 리소스를 포함한다.

```text
AWS Load Balancer Controller
Kubernetes Namespace
ServiceAccount
ConfigMap
Deployment
ClusterIP Service
Ingress
NetworkPolicy
PodDisruptionBudget
EKS Pod Identity Association
```

### 3.3 하나의 State로 합치지 않은 이유

EKS와 Kubernetes 리소스를 같은 실행에 넣으면 다음 문제가 발생할 수 있다.

```text
Terraform 시작
→ Kubernetes Provider 초기화
→ EKS가 아직 생성되지 않음
→ Kubernetes API 연결 실패
```

삭제 시에도 문제가 생긴다.

```text
EKS가 먼저 삭제됨
→ Kubernetes Provider가 Ingress 삭제 불가
→ AWS Load Balancer Controller가 ALB 정리 불가
→ ALB, ENI, Security Group이 남음
→ VPC 삭제 실패 가능
```

따라서 실행 순서를 분리한다.

```text
생성:
Infrastructure apply
→ Platform apply

삭제:
Platform destroy
→ Infrastructure destroy
```

---

## 4. 두 State의 연결 방식

Infrastructure는 다른 구성에서 필요한 값을 Output으로 공개한다.

예:

```hcl
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}
```

Platform은 Infrastructure의 로컬 State를 읽는다.

```hcl
data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = "${path.module}/../infrastructure/terraform.tfstate"
  }
}
```

이름은 `terraform_remote_state`지만 Local State도 읽을 수 있다.

읽은 값은 다음과 같이 사용한다.

```hcl
locals {
  infrastructure = data.terraform_remote_state.infrastructure.outputs
}
```

```text
Infrastructure Resource
→ Infrastructure Output
→ Infrastructure State
→ terraform_remote_state
→ Platform Provider/Resource
```

Output은 Infrastructure의 내부 값을 외부에 공개하는 API와 비슷하다.

모든 값을 공개하지 않고 Platform에서 필요한 값만 공개한다.

---

## 5. AWS 계정 정보 자동 조회

Infrastructure는 현재 Terraform을 실행한 AWS 계정을 조회한다.

```hcl
data "aws_caller_identity" "current" {}
```

여기서 다음 값을 얻는다.

```text
AWS Account ID
현재 IAM Principal ARN
```

사용 목적:

- S3 Bucket 이름에 Account ID 포함
- EKS 관리자 Principal 자동 지정
- Nova Micro Inference Profile ARN 생성
- 계정 번호 하드코딩 방지

예:

```hcl
generation_inference_profile_arn = join("", [
  "arn:aws:bedrock:",
  var.aws_region,
  ":",
  data.aws_caller_identity.current.account_id,
  ":inference-profile/",
  var.bedrock_generation_inference_profile_id
])
```

---

## 6. Module 간 의존성

Terraform은 리소스 값을 직접 참조하면 의존성을 자동으로 계산한다.

예:

```hcl
module "eks" {
  private_subnet_ids = module.vpc.private_subnet_ids
}
```

이 코드로 다음 의존성이 만들어진다.

```text
생성:
VPC
→ Private Subnet
→ EKS

삭제:
EKS
→ Private Subnet
→ VPC
```

이를 암시적 의존성(implicit dependency)이라고 한다.

값 참조로 표현할 수 없는 숨겨진 의존성이 있을 때만 `depends_on`을 사용한다.

예:

```hcl
resource "aws_nat_gateway" "this" {
  depends_on = [aws_internet_gateway.this]
}
```

`depends_on`을 모든 리소스에 무조건 추가하는 것은 좋지 않다. 실제 데이터 참조를 사용하면 Terraform이 더 정확한 의존성 그래프를 만들 수 있다.

---

## 7. VPC Module

VPC Module은 다음 구조를 만든다.

```text
VPC: 10.20.0.0/16

AZ ap-northeast-2a
├─ Public Subnet
└─ Private Subnet

AZ ap-northeast-2c
├─ Public Subnet
└─ Private Subnet
```

구성요소:

```text
VPC
Internet Gateway
Public Subnet 2개
Private Subnet 2개
Public Route Table
Private Route Table
Elastic IP
NAT Gateway
Route Table Association
```

개발 환경에서는 비용 절감을 위해 NAT Gateway를 하나만 생성한다.

```text
Private Subnet 2a ─┐
                   ├→ NAT Gateway 2a
Private Subnet 2c ─┘
```

이는 외부 송신 경로 관점에서 단일 장애점(SPOF)이지만 토이프로젝트 비용을 위한 절충이다.

VPC Module Output:

```text
vpc_id
public_subnet_ids
private_subnet_ids
```

이 값들은 EKS와 Platform에서 사용된다.

---

## 8. ECR Module

ECR Repository 두 개를 생성한다.

```text
gameops-ai-faq-chatbot-web
gameops-ai-faq-chatbot-api
```

설정:

```text
AES256 암호화
Push 시 취약점 스캔
최근 이미지 10개 유지
```

Output:

```hcl
output "repository_urls" {
  value = {
    for name, repository in aws_ecr_repository.this :
    name => repository.repository_url
  }
}
```

Platform은 Repository URL을 Deployment Image 주소로 사용한다.

```text
ECR Module Output
→ Infrastructure Output
→ Platform Remote State
→ Kubernetes Deployment Image
```

---

## 9. EKS Module

EKS Module은 다음을 생성한다.

```text
EKS Cluster IAM Role
Managed Node IAM Role
EKS Cluster
EKS Access Entry
Managed Node Group
EKS Add-ons
```

### 9.1 EKS Cluster IAM Role

EKS Control Plane이 AWS API를 호출할 때 사용하는 IAM Role이다.

Trust Policy:

```text
eks.amazonaws.com
→ AssumeRole 허용
```

### 9.2 Node IAM Role

EKS Worker Node가 사용하는 IAM Role이다.

권한:

```text
AmazonEKSWorkerNodePolicy
AmazonEC2ContainerRegistryReadOnly
AmazonEKS_CNI_Policy
```

역할:

- EKS Node로 동작
- ECR에서 Image Pull
- VPC CNI 네트워크 구성

### 9.3 EKS Cluster 네트워크

EKS Control Plane은 Private Subnet ID를 전달받는다.

```hcl
subnet_ids = var.private_subnet_ids
```

API Endpoint:

```text
Private Access: 활성화
Public Access: 활성화
```

로컬 PC에서 `kubectl` 접근이 필요하므로 Public Endpoint를 사용한다.

Apply 전 다음 값을 현재 PC의 Public IP `/32`로 제한해야 한다.

```hcl
eks_public_access_cidrs = ["203.0.113.10/32"]
```

`0.0.0.0/0`은 학습용 기본값일 뿐 실제 Apply에서는 권장하지 않는다.

### 9.4 EKS Access Entry

현재 Terraform 실행 IAM Principal을 EKS 관리자로 등록한다.

```text
IAM Principal
→ EKS Access Entry
→ AmazonEKSClusterAdminPolicy
```

기존 `aws-auth` ConfigMap 대신 EKS Access API를 사용한다.

### 9.5 Managed Node Group

초기 설정:

```text
Instance Type: t3.medium
Desired: 2
Minimum: 2
Maximum: 2
Disk: 20 GiB
Capacity: On-Demand
```

Node는 두 Private Subnet 중 하나에 배치된다.

### 9.6 EKS Add-ons

```text
CoreDNS
kube-proxy
VPC CNI
EKS Pod Identity Agent
```

VPC CNI에는 NetworkPolicy 기능을 활성화했다.

```hcl
configuration_values = jsonencode({
  enableNetworkPolicy = "true"
})
```

NetworkPolicy YAML 또는 Terraform 리소스만 작성하고 CNI 지원을 활성화하지 않으면 정책이 실제로 적용되지 않을 수 있다.

---

## 10. FAQ S3와 S3 Vectors

Knowledge Base Module은 원본 문서용 S3와 검색용 S3 Vectors를 생성한다.

### 10.1 S3 FAQ Document Bucket

이 Bucket은 Terraform State 저장소가 아니다.

```text
Terraform State
= 로컬 PC에 저장

FAQ S3 Bucket
= Bedrock Knowledge Base 원본 문서 저장
```

설정:

```text
Public Access 차단
AES256 암호화
Versioning 활성화
force_destroy 활성화
```

`force_destroy = true`는 토이프로젝트 종료 시 문서가 남아 있어도 Bucket을 삭제하기 위한 설정이다.

### 10.2 S3 문서 Prefix

Bedrock Data Source는 Bucket 전체가 아니라 다음 Prefix를 사용한다.

```text
dev/
```

예:

```text
s3://bucket/dev/account/password_reset.md
s3://bucket/dev/account/password_reset.md.metadata.json
s3://bucket/dev/payment/item_not_received.md
```

### 10.3 S3 Vectors

```text
Vector Bucket
└─ Vector Index
```

설정:

```text
Data Type: float32
Dimension: 1024
Distance Metric: cosine
```

---

## 11. Bedrock Knowledge Base

### 11.1 Embedding Model

Embedding 모델은 Amazon Titan Text Embeddings V2를 사용한다.

```text
Model ID:
amazon.titan-embed-text-v2:0

Dimension:
1024
```

역할:

```text
FAQ Text
→ 1024차원 Vector
→ S3 Vectors 저장
```

### 11.2 Chunking

```text
Chunk Strategy: Fixed Size
Max Tokens: 500
Overlap: 20%
```

Overlap을 사용하는 이유는 Chunk 경계에서 문맥이 끊기는 문제를 줄이기 위해서다.

### 11.3 Bedrock Service Role

Bedrock Knowledge Base 서비스가 사용하는 IAM Role이다.

권한:

```text
S3 FAQ 문서 읽기
Titan Embedding Model 호출
S3 Vectors 읽기와 쓰기
```

Trust Policy:

```text
bedrock.amazonaws.com
→ AssumeRole 허용
```

### 11.4 Metadata Filter

FAQ 문서는 같은 이름의 Metadata 파일과 함께 관리한다.

```json
{
  "metadataAttributes": {
    "category": "account",
    "category_label": "계정문의",
    "handoff_required": false
  }
}
```

`chatbot-api`는 다음 Filter를 사용한다.

```text
category = account
```

사용자가 선택한 문의 유형 범위에서만 문서를 검색한다.

---

## 12. Nova Micro 연결

답변 생성 모델은 Amazon Nova Micro를 사용한다.

선택 이유:

```text
텍스트 기반 FAQ 챗봇
복잡한 추론 불필요
이미 Knowledge Base가 관련 문서를 검색
비용 최우선
```

서울 리전에서는 Nova Micro를 Foundation Model ARN으로 직접 호출하는 것이 아니라 APAC Inference Profile을 사용한다.

```text
Inference Profile ID:
apac.amazon.nova-micro-v1:0
```

Terraform은 현재 Account ID로 ARN을 만든다.

```text
arn:aws:bedrock:ap-northeast-2:<account-id>:
inference-profile/apac.amazon.nova-micro-v1:0
```

이 값은 다음 흐름으로 전달된다.

```text
Infrastructure Local Value
→ Infrastructure Output
→ Platform Remote State
→ Kubernetes ConfigMap
→ BEDROCK_MODEL_ARN
→ chatbot-api
→ RetrieveAndGenerate
```

Nova Micro Inference Profile은 APAC 여러 리전으로 요청을 라우팅할 수 있다. 서울 리전 고정이 필요한 규제 환경이라면 별도의 검토가 필요하다.

---

## 13. Workload IAM과 Pod Identity

EKS Pod가 AWS API를 호출할 때 Node IAM Role을 공유하지 않고 Pod별 Role을 사용한다.

```text
Pod
→ Kubernetes ServiceAccount
→ EKS Pod Identity Association
→ IAM Role
→ AWS API
```

### 13.1 chatbot-web

```text
AWS 권한 없음
Bedrock 직접 호출 불가
```

### 13.2 chatbot-api

```text
Bedrock Retrieve
Bedrock RetrieveAndGenerate
Nova Micro InvokeModel
```

### 13.3 AWS Load Balancer Controller

```text
ALB 생성 및 삭제
Listener와 Rule 관리
Target Group 관리
Security Group 관리
Pod Target 등록
```

Pod Identity Agent Add-on이 있어야 Pod Identity 자격증명이 Pod에 전달된다.

---

## 14. Platform Provider 연결

Platform은 Infrastructure Output으로 Kubernetes와 Helm Provider를 설정한다.

필요한 값:

```text
EKS Cluster Endpoint
EKS CA Certificate
EKS Cluster Name
AWS Region
```

인증:

```hcl
exec {
  api_version = "client.authentication.k8s.io/v1"
  command     = "aws"
  args = [
    "eks",
    "get-token",
    "--cluster-name",
    local.infrastructure.eks_cluster_name
  ]
}
```

처리 흐름:

```text
Terraform
→ Kubernetes 또는 Helm Provider
→ aws eks get-token
→ 임시 인증 Token 발급
→ EKS Kubernetes API 접속
```

---

## 15. AWS Load Balancer Controller

AWS Load Balancer Controller는 ALB 자체가 아니다.

```text
AWS Load Balancer Controller
= EKS 내부에서 실행되는 Controller Pod

ALB
= Controller가 AWS API로 생성하는 AWS 리소스
```

설치 흐름:

```text
Kubernetes ServiceAccount 생성
→ Pod Identity Association 생성
→ Terraform Helm Provider
→ AWS 공식 Helm Chart 설치
→ Controller Deployment/Pod 실행
```

Controller는 Kubernetes Ingress를 감시한다.

```text
Ingress 생성
→ Controller 감지
→ AWS API 호출
→ ALB 생성
→ Listener 생성
→ Target Group 생성
→ Pod IP 등록
```

Helm Provider를 사용하므로 로컬 PC의 Helm CLI는 필수가 아니다. Terraform Plugin이 Helm 기능을 수행한다.

---

## 16. Kubernetes Namespace와 ConfigMap

Namespace:

```text
gameops-chatbot-dev
```

ConfigMap:

```text
AWS_REGION
RAG_PROVIDER
BEDROCK_KNOWLEDGE_BASE_ID
BEDROCK_MODEL_ARN
CHATBOT_API_BASE_URL
```

중요한 연결:

```text
CHATBOT_API_BASE_URL
= http://chatbot-api-svc:8080
```

Kubernetes 내부 DNS가 `chatbot-api-svc`를 API Pod IP로 해석한다.

---

## 17. chatbot-api Deployment

설정:

```text
Replica: 2
Container Port: 8080
Service Type: ClusterIP
Health Check: /health
ServiceAccount: chatbot-api
AWS 권한: Bedrock Pod Identity
```

환경변수:

```text
ConfigMap
→ chatbot-api Container
```

Readiness Probe:

```text
Pod가 요청을 받을 준비가 되었는지 확인
```

Liveness Probe:

```text
애플리케이션이 정지 상태인지 확인하고 필요하면 재시작
```

---

## 18. chatbot-web Deployment

설정:

```text
Replica: 2
Container Port: 3000
Service Type: ClusterIP
Health Check: /api/health
AWS 권한: 없음
```

Web은 브라우저 요청을 받고 Next.js Route Handler에서 내부 API를 호출한다.

```text
Browser
→ chatbot-web /api/chat
→ chatbot-api-svc:8080/chat
```

브라우저에 내부 API 주소를 노출하지 않는다.

읽기 전용 Root Filesystem을 사용하면서 Next.js 임시 파일 문제를 방지하기 위해 다음 `emptyDir`를 마운트했다.

```text
/tmp
/app/.next/cache
```

---

## 19. ClusterIP Service

Web과 API Service 모두 `ClusterIP`다.

```text
chatbot-web-svc
chatbot-api-svc
```

Web Service가 `LoadBalancer` 타입이 아닌 이유:

```text
외부 공개는 Kubernetes Service가 아니라
Ingress와 ALB가 담당
```

API에는 다음 리소스가 없다.

```text
Ingress 없음
LoadBalancer Service 없음
NodePort 없음
외부 DNS 없음
```

따라서 API는 외부에서 직접 접근할 수 없다.

---

## 20. ALB Ingress

Web만 Ingress에 연결한다.

설정:

```text
Ingress Class: alb
Scheme: internet-facing
Target Type: ip
Health Check Path: /api/health
```

Target Type `ip`:

```text
ALB
→ Pod IP 직접 등록
```

초기에는 ACM 인증서가 없으므로 HTTP Listener를 사용할 수 있다.

```text
acm_certificate_arn = null
→ HTTP 80
```

ACM ARN을 입력하면:

```text
HTTPS 443
SSL Redirect
ACM Certificate
```

로 전환된다.

---

## 21. NetworkPolicy

`chatbot-api` 인바운드는 `chatbot-web` Pod만 허용한다.

```text
chatbot-web Pod
→ chatbot-api:8080 허용

그 외 Pod
→ chatbot-api 차단
```

ClusterIP는 외부 노출을 막지만 Cluster 내부의 모든 Pod 접근을 자동 차단하지는 않는다.

NetworkPolicy는 Cluster 내부 접근 범위를 추가로 제한한다.

---

## 22. 가용성 설정

두 Deployment 모두 Replica 2개를 사용한다.

```text
chatbot-web: 2
chatbot-api: 2
```

Topology Spread Constraint:

```text
가능하면 서로 다른 Node에 Pod 배치
```

현재 설정은:

```text
when_unsatisfiable = ScheduleAnyway
```

완전한 강제 분산보다는 Pod가 아예 실행되지 않는 상황을 피하는 개발 환경 절충이다.

PodDisruptionBudget:

```text
최소 1개 Pod 유지
```

Node Drain이나 유지보수 시 두 Replica가 동시에 중단되는 것을 줄인다.

---

## 23. Terraform과 GitHub Actions의 관리 경계

Terraform은 Deployment 구조를 최초 생성한다.

GitHub Actions는 새 Image를 Build하고 ECR에 Push한 뒤 Deployment Image를 변경한다.

충돌을 막기 위해 Terraform에 다음 설정이 있다.

```hcl
lifecycle {
  ignore_changes = [
    spec[0].template[0].spec[0].container[0].image
  ]
}
```

관리 역할:

```text
Terraform
→ Deployment 구조, Port, Probe, Resource, Service 관리

GitHub Actions
→ Image Tag 변경, Rollout 확인
```

이 설정이 없으면 GitHub Actions가 변경한 Image를 다음 Terraform Apply가 이전 값으로 되돌릴 수 있다.

---

## 24. 초기 ECR Image 문제

Infrastructure Apply 직후 ECR에는 Image가 없을 수 있다.

Platform이 `latest` Image로 Deployment를 만들면:

```text
Pod
→ ImagePullBackOff
```

상태가 될 수 있다.

Deployment 객체 생성 자체가 실패하지 않도록:

```hcl
wait_for_rollout = false
```

로 설정했다.

이후 GitHub Actions가 실제 Image를 Push하고 Deployment Image를 업데이트한다.

---

## 25. FAQ 문서 관리

Git Repository:

```text
knowledge-base/
├─ account/
├─ payment/
├─ game/
└─ security_report/
```

문서와 Metadata를 함께 관리한다.

```text
password_reset.md
password_reset.md.metadata.json
```

업로드:

```powershell
aws s3 sync knowledge-base s3://<bucket>/dev/ --delete
```

S3 업로드 이후 Bedrock Data Source Sync를 실행해야 한다.

```text
파일 업로드
≠ 자동 Ingestion 완료
```

---

## 26. 생성 순서

### Infrastructure

Terraform Dependency Graph가 내부 순서를 계산한다.

개념적 순서:

```text
VPC
→ Subnet/Route/NAT
→ ECR
→ EKS IAM
→ EKS Cluster
→ Node Group
→ EKS Add-ons
→ S3/S3 Vectors
→ Bedrock Knowledge Base
→ Workload IAM
```

### Platform

```text
Namespace
→ ServiceAccount
→ Pod Identity
→ Load Balancer Controller
→ ConfigMap
→ Deployment/Service
→ Ingress
→ ALB 생성
```

---

## 27. 삭제 순서

반드시 Platform부터 삭제한다.

```text
Ingress 삭제
→ Controller가 ALB/Target Group/SG 삭제
→ Deployment와 Service 삭제
→ Controller 삭제
→ Platform State 삭제 완료
→ EKS와 VPC 삭제
```

명령:

```powershell
cd infra\terraform\envs\dev\platform
terraform destroy

cd ..\infrastructure
terraform destroy
```

Infrastructure를 먼저 삭제하면 EKS API 또는 Controller가 사라져 ALB 정리가 실패할 수 있다.

---

## 28. 로컬 State 관리

현재 Terraform은 로컬 PC에서만 실행한다.

```text
infrastructure/terraform.tfstate
platform/terraform.tfstate
```

GitHub Actions는 애플리케이션 Build와 배포만 담당하므로 Terraform State가 필요하지 않다.

State 주의사항:

```text
Git Commit 금지
분실 금지
민감 정보 포함 가능
```

State를 잃어버리면 Terraform이 생성한 리소스를 추적하지 못해 `terraform destroy`가 어려워진다.

---

## 29. 비용 절충

비용을 줄이기 위해 적용한 설정:

```text
NAT Gateway 1개
t3.medium Node 2개
Node 최대 2개
Nova Micro
S3 Vectors
ECR 이미지 최근 10개
```

주요 비용 요소:

```text
EKS Control Plane
EC2 Worker Node
NAT Gateway
ALB
Public IPv4
Bedrock 및 S3 Vectors 사용량
```

Nova Micro 호출 비용보다 EKS, Node, NAT, ALB 실행 시간이 더 큰 비용 요소가 될 가능성이 높다.

---

## 30. Apply 전 체크리스트

1. AWS 로그인 확인

```powershell
aws sts get-caller-identity
```

2. EKS Public API CIDR 제한

```hcl
eks_public_access_cidrs = ["현재-PC-Public-IP/32"]
```

3. Infrastructure Plan 검토

```powershell
terraform plan
```

4. Infrastructure Apply 후 Node 확인

```powershell
kubectl get nodes
```

5. ECR Image Push

6. Platform Apply

7. FAQ 문서 S3 업로드

8. Bedrock Data Source Sync

9. ALB 주소 확인

10. 실습 종료 후 Platform과 Infrastructure 순서로 Destroy

---

## 31. 현재 검증 결과

현재 코드에 대해 다음 검증을 완료했다.

```text
terraform fmt: 성공
Infrastructure validate: 성공
Platform validate: 성공
Infrastructure plan: 성공
```

Plan 결과:

```text
48 to add
0 to change
0 to destroy
```

서울 리전 서비스 확인:

```text
S3 Vectors API 지원
Titan Text Embeddings V2 지원
APAC Nova Micro Inference Profile ACTIVE
```

아직 실제 `terraform apply`는 실행하지 않았다.

---

## 32. 핵심 요약

```text
Infrastructure State
= AWS 기반 리소스 생명주기

Platform State
= EKS 내부 리소스 생명주기

Infrastructure Output
= 두 State를 연결하는 공개 인터페이스

terraform_remote_state
= Platform이 Infrastructure 결과를 읽는 방법

Pod Identity
= Pod별 AWS IAM 권한 분리

AWS Load Balancer Controller
= Kubernetes Ingress를 AWS ALB로 변환

ClusterIP + NetworkPolicy
= chatbot-api 내부 격리

ignore_changes(image)
= Terraform과 GitHub Actions의 이미지 관리 충돌 방지
```

최종 연결 구조:

```text
Terraform Infrastructure
→ Output
→ Terraform Platform
→ Kubernetes ConfigMap/ServiceAccount/Deployment
→ chatbot-api
→ Bedrock Knowledge Base
→ S3 Vectors
```
