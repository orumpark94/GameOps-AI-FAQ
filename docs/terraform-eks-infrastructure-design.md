# Terraform 및 EKS 인프라 설계

## 설계 목표

AWS 리소스 생성 자체보다 변경 책임과 권한 경계를 명확히 하는 데 초점을 둡니다. 재사용 가능한 Child Module과 환경별 Root Module을 분리하고 AWS 수명주기와 Kubernetes 수명주기를 별도 State로 관리합니다.

## Terraform 구조

```text
infra/terraform/
├─ modules/
│  ├─ vpc/             # Subnet, Route, IGW, NAT
│  ├─ ecr/             # Repository, Scan, Lifecycle
│  ├─ eks/             # Cluster, Node Group, Add-on, Access Entry
│  ├─ knowledge-base/  # S3, S3 Vectors, Bedrock KB/Data Source
│  ├─ workload-iam/    # ALB Controller/API Pod Identity Role
│  └─ github-oidc/     # GitHub 신뢰 정책과 배포 권한
└─ envs/dev/
   ├─ infrastructure/  # AWS Provider Root Module
   └─ platform/        # AWS/Kubernetes/Helm Provider Root Module
```

```text
Infrastructure Output
├─ Local State → Platform terraform_remote_state
└─ SSM Parameter Store → GitHub Actions
```

Platform에는 EKS 연결 정보, Subnet, ECR URL, IAM Role ARN, Bedrock ID가 전달됩니다. GitHub Actions에는 배포에 필요한 ECR URL과 Knowledge Base 위치만 SSM으로 제공합니다.

## State 분리

EKS와 Kubernetes 리소스를 한 State에서 생성하면 EKS API 준비 전에 Kubernetes/Helm Provider가 초기화될 수 있습니다. 삭제 시 EKS가 먼저 사라지면 Controller가 Ingress 기반 ALB를 정리하지 못할 수도 있습니다.

```text
생성: infrastructure apply → 이미지 준비 → platform apply
삭제: platform destroy → infrastructure destroy
```

현재 Local State 경로 연결은 개인 프로젝트에는 단순하지만 병렬 실행, Locking, 재해 복구가 필요한 환경에는 부적절합니다.

## AWS 인프라

### VPC와 ECR

`10.20.0.0/16` VPC를 두 AZ로 나눠 Public/Private Subnet을 구성합니다. EKS Node는 Private Subnet에서 단일 NAT Gateway로 외부에 접근합니다. ECR은 Web/API Repository를 분리하고 Push Scan, AES256 암호화, 최근 이미지 10개 유지 정책을 적용합니다. 재현 가능한 배포에는 Mutable `latest` 대신 Commit SHA 태그를 사용합니다.

### EKS

- API 기반 Access Entry로 관리자 Principal을 명시
- Public Endpoint CIDR 제한과 Private Endpoint 동시 활성화
- Private Subnet의 Managed Node Group 2대(`t3.medium`, On-Demand)
- CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity Agent 관리
- VPC CNI NetworkPolicy 기능 활성화

Kubernetes 버전은 변수 기본값을 사용하므로 정확한 적용 버전은 `variables.tf`와 State를 함께 확인해야 합니다.

### Knowledge Base

Data Source는 게임문의, 결제문의, 계정문의, 해킹/신고로 구분된 FAQ 문서 16개입니다. 공지사항, 패치노트, 운영정책 원문은 현재 데이터 소스에 포함하지 않습니다. 카테고리 디렉터리는 관리 편의를 위한 구조이고 실제 검색 범위는 각 문서의 `category` 메타데이터로 제한합니다.

원문 S3 Bucket에 Public Access Block, Versioning, AES256 암호화를 적용합니다. S3 Vectors Index는 Titan Text Embeddings V2의 1,024차원 `float32` 벡터와 Cosine Distance를 사용합니다. Data Source는 `dev/` Prefix만 읽고 500 Token, 20% Overlap의 Fixed-size Chunking을 적용합니다.

개발 환경 Destroy 편의를 위한 `force_destroy`는 운영 데이터 보존에는 위험합니다. 운영 환경에서는 제거하거나 별도 백업·보존 정책이 필요합니다.

## EKS 플랫폼

AWS Load Balancer Controller와 API는 EKS Pod Identity로 각각 별도 IAM Role을 받습니다. 애플리케이션 Namespace에는 Web/API Deployment, ClusterIP Service, Ingress, NetworkPolicy, PDB를 생성합니다.

두 Deployment의 공통 운영 설정:

- Replica 2개와 Hostname 기준 Topology Spread
- `maxUnavailable=0`, `maxSurge=1` Rolling Update
- Readiness/Liveness Probe와 Resource Request/Limit
- non-root, Read-only Root Filesystem, Linux Capability 전체 제거

Web은 `/tmp`와 Next.js Cache에 `emptyDir`를 Mount합니다. API는 ConfigMap에서 Bedrock 설정을 받고 Pod Identity로 AWS 자격 증명을 획득합니다.

## IAM 최소 권한

| 역할 | 주요 권한 |
|---|---|
| Bedrock Knowledge Base | 지정 S3 Prefix 읽기, Embedding 호출, S3 Vectors 사용 |
| chatbot-api | 지정 Knowledge Base Retrieve, 지정 Model Invoke |
| ALB Controller | Controller가 요구하는 ALB/EC2 관련 정책 |
| GitHub Actions | SSM 읽기, 두 ECR Push, 지정 S3 Prefix, Ingestion 실행/조회 |

GitHub Trust Policy는 저장소·브랜치 Subject와 `sts.amazonaws.com` Audience를 검사합니다. 장기 Access Key는 CI에 저장하지 않습니다.

## 관리 경계와 개선 과제

Terraform은 인프라와 초기 Deployment 형태를 관리하고 이후 이미지 태그는 배포 스크립트가 관리합니다. `ignore_changes`는 이 책임 분리를 구현하지만 Drift 탐지 범위를 줄입니다.

운영 수준으로 발전시키려면 Remote Backend와 State Locking, HTTPS/Route 53/WAF, Secret 관리, 로그·메트릭·알림, Image Scan Gate, 승인 기반 배포와 자동 Rollback, 다중 환경 구성을 추가해야 합니다.
