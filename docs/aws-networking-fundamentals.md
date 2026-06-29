# AWS 네트워크 설계

이 문서는 현재 Terraform 구현의 요청 경로와 보안 경계를 설명합니다.

## 토폴로지

```text
VPC 10.20.0.0/16
├─ ap-northeast-2a
│  ├─ Public  10.20.0.0/24  ─ ALB, NAT Gateway
│  └─ Private 10.20.10.0/24 ─ EKS Node/Pod
└─ ap-northeast-2c
   ├─ Public  10.20.1.0/24  ─ ALB
   └─ Private 10.20.11.0/24 ─ EKS Node/Pod
```

Public Subnet의 기본 경로는 Internet Gateway, 두 Private Subnet의 기본 경로는 2a의 단일 NAT Gateway를 향합니다. ALB는 Public Subnet에 생성되고 EKS Managed Node Group은 Private Subnet에서만 실행됩니다.

## 인바운드 요청 경로

```text
Internet → ALB → chatbot-web-svc:3000 → chatbot-web Pod
                                           ↓
                              chatbot-api-svc:8080 → chatbot-api Pod
```

Ingress는 Web Service만 Backend로 등록합니다. API는 `ClusterIP`이며 외부 Load Balancer나 Ingress 경로가 없습니다. Next.js Route Handler가 서버 측에서 API를 호출하므로 브라우저에 내부 Service DNS가 노출되지 않습니다.

API의 Kubernetes NetworkPolicy는 Web Pod에서 TCP 8080으로 들어오는 연결만 허용합니다. VPC CNI Add-on의 `enableNetworkPolicy=true`가 실제 적용 전제입니다.

## 아웃바운드와 EKS API

Private Subnet의 Pod는 NAT Gateway를 통해 ECR, Bedrock 등 Public AWS Endpoint에 접근합니다. 현재 VPC Endpoint는 없습니다. 비용과 보안을 최적화하려면 ECR API/DKR, S3, STS 등 필요한 Endpoint를 트래픽 기준으로 검토해야 합니다.

EKS Endpoint는 Private/Public Access를 모두 활성화합니다. Public Endpoint는 `eks_public_access_cidrs`만 허용하고 인증은 EKS Access Entry와 AWS CLI 토큰을 사용합니다. Public CIDR 제한은 인증을 대체하지 않으며 작업자 IP 변경 시 갱신해야 합니다.

## 가용성과 트레이드오프

- ALB와 EKS 워크로드는 두 Availability Zone을 사용합니다.
- Topology Spread는 두 노드에 Replica를 분산하려 하고 PDB는 최소 1개 Pod를 유지합니다.
- 단일 NAT Gateway는 비용을 줄이지만 2a 장애 시 외부 송신의 단일 장애점(SPOF)입니다.
- Node Group은 2대로 고정되어 비용 예측은 단순하지만 자동 확장성은 제한됩니다.

운영 환경에서는 AZ별 NAT Gateway, HPA와 노드 자동 확장, HTTPS 강제, Route 53, WAF, VPC Flow Logs를 검토해야 합니다.
