# GameOps AI FAQ

게임 고객센터의 4개 문의 유형(게임문의, 결제문의, 계정문의, 해킹/신고)에 대한 FAQ 문서를 근거로 답변하는 Amazon Bedrock 기반 RAG(Retrieval-Augmented Generation) 챗봇입니다. 인프라는 Terraform으로 선언하고, 애플리케이션은 Amazon EKS에서 운영하며, GitHub Actions와 OIDC(OpenID Connect)로 이미지 및 FAQ 문서 배포를 자동화했습니다.

> 단순 LLM API 호출보다 인프라 경계, 최소 권한, 검색 품질 제어, 안전한 배포 흐름을 설계하고 구현한 포트폴리오 프로젝트입니다.

## 핵심 구현

- Terraform 모듈로 VPC, ECR, EKS, IAM, S3 Vectors, Bedrock Knowledge Base 구성
- AWS 인프라와 Kubernetes 플랫폼을 별도 State로 분리해 Provider 초기화 및 삭제 순서 문제 해소
- Public ALB → Next.js Web → 내부 Fastify API로 외부 노출 범위 제한
- EKS Pod Identity로 API와 AWS Load Balancer Controller에 역할별 최소 권한 부여
- 카테고리 메타데이터 필터, 쿼리 재작성, 검색 점수 임계값으로 RAG 답변 신뢰성 보강
- GitHub OIDC로 장기 AWS Access Key 없이 ECR Push 및 Knowledge Base 동기화
- Rolling Update, Health Probe, PDB(Pod Disruption Budget), NetworkPolicy, non-root 컨테이너 적용

## 서비스 범위

현재 Knowledge Base는 공지사항, 패치노트, 운영정책 원문을 수집하는 구조가 아닙니다. 아래 4개 문의 유형별로 작성한 16개의 FAQ 문서가 실제 데이터 소스입니다.

| 화면 표시 | 식별자 | 현재 FAQ 주제 |
|---|---|---|
| 게임문의 | `game` | 캐릭터 삭제, 접속 문제, 아이템 유실, 퀘스트 진행 문제 |
| 결제문의 | `payment` | 중복 결제, 구매 아이템 미지급, 결제 실패, 환불 요청 |
| 계정문의 | `account` | 계정 잠금, 계정 찾기, 계정 정보 변경, 비밀번호 재설정 |
| 해킹/신고 | `security_report` | 이용자 신고, 해킹 의심, 피싱 신고, 무단 결제 |

일부 FAQ 본문은 사용자가 공식 공지나 운영정책을 확인하도록 안내하지만, 공지 또는 운영정책 문서 자체를 검색 데이터로 저장한 것은 아닙니다.

## 아키텍처

```text
사용자
  → Internet-facing ALB
  → chatbot-web (Next.js, ClusterIP)
  → chatbot-api (Fastify, ClusterIP)
      ├─ 대화 이력이 있으면 Nova Micro로 검색 질의 재작성
      ├─ Bedrock Knowledge Base에서 선택 카테고리의 FAQ 검색
      └─ 최고 점수 문서 조각 1개를 근거로 Nova Micro 답변 생성
           └─ S3 Vectors index
```

FAQ 문서는 `knowledge-base/`에서 관리합니다. GitHub Actions는 각 Markdown 문서의 메타데이터 파일 존재 여부와 JSON 문법을 검사한 뒤 S3의 `dev/` Prefix에 동기화하고 Bedrock Ingestion Job을 실행합니다.

## 기술 스택

| 영역 | 기술 |
|---|---|
| Frontend | Next.js, React, TypeScript |
| Backend | Fastify, TypeScript, Zod, AWS SDK for JavaScript v3 |
| AI/RAG | Amazon Bedrock Knowledge Bases, Nova Micro, Titan Text Embeddings V2, S3 Vectors |
| Runtime | Amazon EKS, Kubernetes, Helm, AWS Load Balancer Controller |
| IaC | Terraform 1.7+, AWS Provider 6.x |
| CI/CD | GitHub Actions, GitHub OIDC, Amazon ECR, SSM Parameter Store |

## 주요 설계 결정

| 결정 | 이유 | 현재 한계 |
|---|---|---|
| Infrastructure/Platform State 분리 | EKS 준비 전 Kubernetes Provider 접속 실패 방지 | Platform이 로컬 State 경로에 결합됨 |
| 단일 NAT Gateway | 개발 환경 비용 절감 | 외부 송신 경로의 단일 장애점(SPOF) |
| API를 ClusterIP로만 제공 | Bedrock 권한을 가진 백엔드를 인터넷에서 격리 | Web 계층을 거치는 추가 홉 |
| 이미지 배포를 Terraform과 분리 | Platform Apply가 배포된 SHA 태그를 되돌리지 않음 | 이미지의 최종 상태는 Terraform 밖에서 관리 |
| Local State | 개인 개발 환경의 운영 복잡도 최소화 | 협업·잠금·복구에 부적합 |

## 저장소 구조

```text
apps/                         # Next.js Web, Fastify API
infra/terraform/modules/      # 재사용 가능한 AWS 모듈
infra/terraform/envs/dev/     # infrastructure/platform Root Module
knowledge-base/               # FAQ 원문과 Bedrock 메타데이터
.github/workflows/            # 이미지 및 Knowledge Base 배포
scripts/deploy-app.ps1        # EKS 이미지 배포와 Rollout 검증
docs/                         # 설계 문서
```

## 실행 순서

Terraform 1.7+, AWS CLI, kubectl, Docker가 필요합니다. 실제 AWS 비용이 발생하며 Bedrock 모델과 S3 Vectors의 리전 지원 여부를 먼저 확인해야 합니다.

```powershell
cd infra\terraform\envs\dev\infrastructure
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 초기 이미지를 ECR에 Push한 후
cd ..\platform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output load_balancer_hostname
```

삭제는 ALB가 먼저 정리되도록 반드시 `platform` → `infrastructure` 순서로 수행합니다.

## 문서

- [Terraform 및 EKS 설계](docs/terraform-eks-infrastructure-design.md)
- [AWS 네트워크 설계](docs/aws-networking-fundamentals.md)
- [RAG 답변 안전성과 대화 처리](docs/rag-answer-safety-and-conversation.md)
- [Terraform 실행 가이드](infra/terraform/README.md)

## 현재 범위와 개선 과제

현재 구성은 단일 `dev` 환경의 포트폴리오 구현입니다. 운영 수준으로 확장하려면 Remote State와 Locking, 다중 NAT Gateway, HTTPS/DNS, 관측성, HPA, WAF, 자동화 테스트와 배포 승인 단계를 추가해야 합니다. 검색 점수 임계값 `0.6`도 대표 질문 데이터셋으로 평가해 조정해야 하는 초기값입니다.
