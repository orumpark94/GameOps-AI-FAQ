
전체 순서

1. Infrastructure Terraform Apply
2. Infrastructure 생성 결과 검증
3. GitHub Actions용 AWS Role ARN 등록
4. GitHub Actions로 이미지 Build 및 ECR Push
5. GitHub Actions로 FAQ 문서 S3 Sync 및 Ingestion
6. Platform Terraform Apply
7. SHA 태그 기반 애플리케이션 배포
8. ALB 및 RAG 동작 검증
9. 테스트 완료 후 역순 Destroy


1. Infrastructure 생성
현재 저장한 계획을 적용합니다.
terraform apply "tfplan"
이 단계에서 AWS에 다음 인프라가 생성됩니다.
VPC
├─ Public Subnet 2개
├─ Private Subnet 2개
├─ Internet Gateway
├─ NAT Gateway 1개
└─ Route Table

ECR
├─ gameops-ai-faq-chatbot-web
└─ gameops-ai-faq-chatbot-api

EKS
├─ EKS Control Plane
├─ Managed Node Group
├─ EKS Add-ons
└─ EKS Access Entry

Bedrock RAG
├─ FAQ 문서용 S3 Bucket
├─ S3 Vectors
├─ Bedrock Knowledge Base
└─ Data Source

IAM
├─ chatbot-api Pod Identity Role
├─ AWS Load Balancer Controller Role
└─ GitHub Actions OIDC Role

SSM Parameter Store
└─ 현재 AWS 리소스 ID와 URL
apply는 EKS와 Bedrock Knowledge Base 때문에 상당한 시간이 걸릴 수 있습니다.
중간에 실패하더라도 성공한 리소스는 Terraform State에 기록됩니다. 원인을 수정한 뒤 다시 실행하면 됩니다.
terraform apply


2. 생성 결과 확인
Apply가 완료되면 다음 명령으로 Output을 확인합니다.
terraform output
EKS 노드 접근을 확인합니다.
aws eks update-kubeconfig `
  --region ap-northeast-2 `
  --name gameops-ai-faq-dev

kubectl get nodes
kubectl get pods -A
정상이라면 노드 2개가 Ready 상태여야 합니다.
NAME              STATUS   ROLES
ip-10-20-10-x     Ready    <none>
ip-10-20-11-x     Ready    <none>
SSM Parameter Store도 확인합니다.
aws ssm get-parameters-by-path `
  --path "/gameops-ai-faq/dev" `
  --recursive
Terraform이 생성한 실제 ECR URL, S3 Bucket 이름, Knowledge Base ID 등이 저장되어 있어야 합니다.
이 구조 덕분에 인프라를 삭제하고 다시 생성해 ID가 바뀌어도 GitHub Actions는 SSM에서 최신 값을 읽습니다.


3. GitHub Actions Role 등록
Terraform Output에서 GitHub Actions용 Role ARN을 조회합니다.
terraform output -raw github_actions_role_arn
출력 예시:
arn:aws:iam::863676520919:role/gameops-ai-faq-dev-github-actions
GitHub 저장소에서 다음 위치로 이동합니다.
Settings
→ Secrets and variables
→ Actions
→ Variables
→ New repository variable

등록할 값:
Name:  AWS_ROLE_ARN
Value: Terraform에서 출력된 Role ARN
이 값은 최초 1회 등록하면 됩니다. 같은 이름의 IAM Role을 다시 생성한다면 ARN은 유지됩니다.


4. 애플리케이션 이미지 생성
GitHub Actions에서 다음 Workflow를 수동 실행합니다.

Actions
→ Build and Push Application Images
→ Run workflow
→ service: all
Workflow 파일은 [app-images.yml](D:/SJPARK/GameOps-AI-FAQ/.github/workflows/app-images.yml)입니다.

실행 흐름:
GitHub OIDC Token 발급
→ AWS IAM Role Assume
→ SSM에서 ECR URL 조회
→ chatbot-api Linux Image Build
→ chatbot-web Linux Image Build
→ ECR에 Commit SHA Tag Push
→ ECR에 latest Tag Push
ECR에는 다음처럼 저장됩니다.
gameops-ai-faq-chatbot-api:<commit-sha>
gameops-ai-faq-chatbot-api:latest

gameops-ai-faq-chatbot-web:<commit-sha>
gameops-ai-faq-chatbot-web:latest

여기서 Commit SHA를 기록해 둡니다. 이후 정확한 버전 배포에 사용합니다.


5. FAQ 문서 동기화
GitHub Actions에서 다음 Workflow를 실행합니다.
Actions
→ Sync Knowledge Base Documents
→ Run workflow
처리 흐름:
FAQ Markdown 및 Metadata 검증
→ SSM에서 현재 S3 Bucket과 Knowledge Base ID 조회
→ knowledge-base/ 내용을 S3 dev/에 동기화
→ Bedrock Ingestion Job 실행
→ 문서 Chunking
→ Embedding 생성
→ S3 Vectors 저장
→ COMPLETE까지 대기
Workflow가 COMPLETE로 끝나야 RAG 검색에 문서가 반영됩니다.
이미지 Workflow와 Knowledge Base Workflow는 서로 직접 의존하지 않으므로 병렬 실행도 가능합니다.


6. Platform Terraform 적용
이미지가 ECR에 존재하고 EKS 노드가 Ready인 것을 확인한 다음 진행합니다.

cd D:\SJPARK\GameOps-AI-FAQ\infra\terraform\envs\dev\platform

Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply "tfplan"
Platform은 Infrastructure의 로컬 State Output을 참조합니다.
Infrastructure State
→ EKS Cluster 이름과 Endpoint
→ ECR Repository URL
→ Bedrock Knowledge Base ID
→ IAM Role ARN
→ VPC ID
Platform 단계에서 생성되는 항목:
AWS Load Balancer Controller
Pod Identity Association
gameops-chatbot-dev Namespace
chatbot-web Deployment/Service
chatbot-api Deployment/Service
Ingress
ConfigMap
NetworkPolicy
PodDisruptionBudget
통신 구조는 다음과 같습니다.
Internet
→ ALB
→ chatbot-web Service
→ chatbot-web Pod
→ chatbot-api ClusterIP Service
→ chatbot-api Pod
→ Bedrock Knowledge Base
chatbot-api는 ClusterIP이므로 외부에서 직접 접근할 수 없습니다.


7. 정확한 이미지 버전 배포
Platform은 처음에 latest 이미지를 사용합니다. 이후 GitHub Actions에서 생성된 Commit SHA로 이미지를 고정합니다.
프로젝트 루트에서 실행합니다.
cd D:\SJPARK\GameOps-AI-FAQ

.\scripts\deploy-app.ps1 `
  -Service all `
  -ImageTag <GITHUB_COMMIT_SHA>
스크립트 처리 과정:
Terraform Output 조회
→ AWS 로그인 확인
→ EKS kubeconfig 갱신
→ ECR에 SHA Tag 존재 여부 확인
→ chatbot-api 이미지 변경
→ API Rollout 완료 대기
→ chatbot-web 이미지 변경
→ Web Rollout 완료 대기
실제 스크립트는 [deploy-app.ps1](D:/SJPARK/GameOps-AI-FAQ/scripts/deploy-app.ps1)입니다.


8. 최종 검증
Pod 상태:
kubectl get pods -n gameops-chatbot-dev
Deployment 상태:
kubectl get deployment -n gameops-chatbot-dev
Service 확인:
kubectl get service -n gameops-chatbot-dev
Ingress와 ALB 주소 확인:
kubectl get ingress -n gameops-chatbot-dev
또는:
cd infra\terraform\envs\dev\platform
terraform output -raw load_balancer_hostname
브라우저 접속:
http://<ALB-DNS-NAME>
확인할 최종 기능:
웹 UI 접근
→ 카테고리 선택
→ 질문 전송
→ chatbot-web에서 chatbot-api 내부 호출
→ Metadata Category Filter 적용
→ Bedrock 검색
→ Score Threshold 검사
→ Nova Micro 답변 생성
→ 출처 표시
→ 검색 실패 시 고객센터 안내


9. 테스트 종료 후 삭제
반드시 Platform을 먼저 삭제합니다.
cd D:\SJPARK\GameOps-AI-FAQ\infra\terraform\envs\dev\platform
terraform destroy
그다음 Infrastructure를 삭제합니다.
cd ..\infrastructure
terraform destroy
순서가 중요한 이유는 Platform의 Ingress를 먼저 삭제해야 AWS Load Balancer Controller가 ALB와 Target Group을 정리할 수 있기 때문입니다.
핵심 실행 순서는 다음 한 줄로 정리됩니다.
Infrastructure Apply
→ GitHub Role 등록
→ Image Push + FAQ Ingestion
→ Platform Apply
→ SHA 이미지 배포
→ 기능 검증
→ Platform Destroy
→ Infrastructure Destroy