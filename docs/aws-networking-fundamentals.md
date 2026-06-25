# AWS 네트워크 핵심 개념 정리

이 문서는 GameOps AI FAQ 프로젝트의 AWS 네트워크를 이해하기 위한 학습 자료다.

다음 구성요소가 어떤 범위에 속하고, 서로 어떤 관계를 가지며, 실제 패킷이 어떻게 이동하는지를 설명한다.

- VPC
- Availability Zone
- Subnet
- Route Table
- Internet Gateway
- NAT Gateway
- Application Load Balancer
- Security Group

---

## 1. 전체 그림부터 이해하기

현재 프로젝트에서 목표로 하는 네트워크 구조를 단순화하면 다음과 같다.

```text
AWS Seoul Region: ap-northeast-2
└─ VPC: 10.20.0.0/16
   ├─ Internet Gateway
   │
   ├─ AZ: ap-northeast-2a
   │  ├─ Public Subnet A:  10.20.0.0/24
   │  │  ├─ ALB ENI
   │  │  └─ NAT Gateway A
   │  └─ Private Subnet A: 10.20.10.0/24
   │     └─ EKS Node / Pod
   │
   └─ AZ: ap-northeast-2c
      ├─ Public Subnet C:  10.20.1.0/24
      │  └─ ALB ENI
      └─ Private Subnet C: 10.20.11.0/24
         └─ EKS Node / Pod
```

외부 사용자의 요청 흐름은 다음과 같다.

```text
사용자
→ Route 53
→ Internet-facing ALB
→ chatbot-web Pod
→ chatbot-api Service
→ chatbot-api Pod
→ Amazon Bedrock
```

네트워크 관점에서 더 자세히 표현하면 다음과 같다.

```text
Internet
→ Internet Gateway
→ Public Subnet의 ALB ENI
→ ALB Listener / Rule
→ Target Group
→ Private Subnet의 chatbot-web Pod
```

---

## 2. 리소스 소속 관계

먼저 각 리소스가 어디에 속하는지 구분해야 한다.

| 구성요소 | 범위 또는 소속 | 핵심 역할 |
|---|---|---|
| Region | 지리적 AWS 서비스 영역 | 서울, 도쿄 등 지역 구분 |
| Availability Zone | Region 내부 장애 격리 영역 | 전원·네트워크 장애 영향 분리 |
| VPC | Region 범위 | 논리적으로 격리된 사설 네트워크 |
| Subnet | VPC 소속, 단일 AZ 범위 | 리소스가 실제 IP를 할당받는 하위 네트워크 |
| Route Table | VPC 소속 | 연결된 Subnet의 목적지별 다음 경로 결정 |
| Internet Gateway | VPC에 연결 | VPC와 인터넷 사이의 연결 지점 |
| NAT Gateway | 특정 Subnet과 AZ에 배치 | Private 리소스의 외부 송신 지원 |
| ALB | 특정 VPC와 여러 Subnet에 연결 | HTTP/HTTPS 요청 분산 |
| Security Group | VPC 소속, ENI에 연결 | 리소스 단위 통신 허용 |

핵심 관계는 다음과 같다.

```text
Region
└─ VPC
   ├─ Internet Gateway
   ├─ Route Tables
   ├─ Security Groups
   ├─ Subnet A ── AZ A
   └─ Subnet C ── AZ C
```

ALB와 IGW는 상하 관계가 아니다.

```text
잘못된 이해

IGW
└─ ALB
```

```text
정확한 이해

VPC
├─ IGW
└─ ALB
```

인터넷용 ALB가 외부와 통신할 때 같은 VPC에 연결된 IGW 경로를 사용하는 것이다.

---

## 3. Region과 Availability Zone

### 3.1 Region

Region은 지리적으로 구분된 AWS 서비스 영역이다.

```text
ap-northeast-2 = 서울 Region
ap-northeast-1 = 도쿄 Region
```

서울과 부산처럼 멀리 떨어진 지역을 비교하는 개념은 일반적으로 서로 다른 Region에 더 가깝다.

### 3.2 Availability Zone

Availability Zone(AZ)은 한 Region 내부의 장애 격리 영역이다.

```text
서울 Region
├─ ap-northeast-2a
├─ ap-northeast-2b
├─ ap-northeast-2c
└─ ap-northeast-2d
```

`2a`를 서울, `2c`를 부산으로 이해하면 안 된다. 둘 다 서울 Region 내부에 있다.

개념적으로는 다음과 같다.

```text
서울 지역의 인프라 구역 A
서울 지역의 인프라 구역 C
```

AZ 하나가 물리적 데이터센터 건물 정확히 하나라는 뜻은 아니다. 하나 이상의 데이터센터로 구성될 수 있다.

AZ는 네트워크가 아니라 물리적 장애를 분리하기 위한 배치 영역이다.

---

## 4. VPC

VPC(Virtual Private Cloud)는 AWS 안에 만드는 논리적으로 격리된 사설 네트워크다.

예:

```text
VPC CIDR: 10.20.0.0/16
```

이 CIDR은 VPC가 사용할 수 있는 전체 IPv4 주소 범위를 의미한다.

```text
10.20.0.0 ~ 10.20.255.255
```

하지만 EC2나 EKS Node를 VPC CIDR에 직접 배치하지 않는다. VPC 주소 공간을 Subnet으로 나눈 후, 리소스를 Subnet에 배치한다.

```text
VPC: 10.20.0.0/16
└─ Subnet: 10.20.10.0/24
   └─ EC2: 10.20.10.15
```

### 온프레미스 관점

온프레미스와 완전히 같지는 않지만 다음처럼 비교할 수 있다.

```text
기업 전체 사설 네트워크 또는 하나의 라우팅 도메인
≈ VPC

서버망·업무망·DB망의 VLAN/IP 대역
≈ Subnet

라우터의 목적지별 경로표
≈ Route Table

인터넷 경계 연결 지점
≈ Internet Gateway

서버 NIC 단위 방화벽
≈ Security Group
```

서울 본사와 부산 지사가 각각 독립된 네트워크이고 VPN으로 연결되어 있다면, AWS에서는 VPC 두 개와 VPC Peering 또는 Transit Gateway 구조에 더 가깝다.

---

## 5. Subnet

Subnet은 VPC 주소 공간을 나눈 실제 Layer 3 하위 네트워크다.

```text
VPC: 10.20.0.0/16

Public Subnet A:  10.20.0.0/24
Public Subnet C:  10.20.1.0/24
Private Subnet A: 10.20.10.0/24
Private Subnet C: 10.20.11.0/24
```

### 5.1 Subnet은 하나의 AZ에만 속한다

Subnet 하나를 두 AZ가 공동으로 사용할 수 없다.

```text
Subnet 10.20.10.0/24
└─ ap-northeast-2a에만 존재
```

`ap-northeast-2c`에 리소스를 배치하려면 별도의 Subnet이 필요하다.

```text
AZ 2a → Private Subnet A → EKS Node A
AZ 2c → Private Subnet C → EKS Node C
```

따라서 EKS Worker Node를 두 AZ에 분산하려면 각 AZ에 Subnet이 있어야 한다.

### 5.2 Public과 Private은 고정된 Subnet 종류가 아니다

AWS에서 Public Subnet과 Private Subnet은 별도의 생성 타입이 아니다. 주로 연결된 Route Table의 기본 경로로 구분한다.

Public Subnet:

```text
0.0.0.0/0 → Internet Gateway
```

Private Subnet:

```text
0.0.0.0/0 → NAT Gateway
```

격리 Subnet:

```text
인터넷 방향의 0.0.0.0/0 경로 없음
```

단, IGW 경로가 있다는 사실만으로 Subnet 안의 모든 리소스가 외부에서 공개되는 것은 아니다. Public IPv4, Security Group, Network ACL 등의 조건도 필요하다.

---

## 6. Route Table

Route Table은 패킷의 목적지를 보고 다음 전달 대상(next hop)을 결정하는 경로표다.

Route Table은 방화벽이 아니다.

```text
Route Table
= 어디로 보낼 것인가?

Security Group
= 이 통신을 허용할 것인가?
```

### 6.1 Route Table의 소속

Route Table은 Subnet 소속이 아니라 VPC 소속이다.

```text
VPC
├─ Route Table A
├─ Route Table B
├─ Subnet A ── Route Table A 사용
└─ Subnet B ── Route Table A 사용
```

Terraform에서도 Route Table 생성 시 VPC를 지정한다.

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
}
```

### 6.2 Subnet과 Route Table의 관계

Subnet 하나는 한 번에 하나의 Route Table을 사용한다.

Route Table 하나는 여러 Subnet이 공유할 수 있다.

```text
Subnet → Route Table
하나만 사용

Route Table → Subnet
여러 Subnet이 공유 가능
```

명시적으로 연결하지 않은 Subnet은 VPC의 Main Route Table을 사용한다.

### 6.3 `local` 경로

VPC에는 VPC CIDR을 대상으로 하는 `local` 경로가 존재한다.

```text
Destination    Target
10.20.0.0/16   local
```

이 경로는 VPC 내부 Subnet 간 라우팅을 가능하게 한다.

```text
10.20.10.15
→ local
→ 10.20.11.20
```

하지만 `local` 경로가 있다고 실제 통신이 무조건 허용되는 것은 아니다.

다음 정책도 허용되어야 한다.

- Security Group
- Network ACL
- 운영체제 방화벽
- Kubernetes NetworkPolicy
- 애플리케이션 수신 포트

즉, 라우팅 가능성과 통신 허용은 별개다.

### 6.4 인터넷 기본 경로

```text
0.0.0.0/0 → IGW
```

`0.0.0.0/0`은 다른 더 구체적인 경로에 일치하지 않는 모든 IPv4 목적지를 의미한다.

인터넷으로 향하는 트래픽이 보통 이 경로를 사용한다.

### 6.5 VPC Peering 경로

다른 VPC 주소가 다음과 같다고 가정한다.

```text
상대 VPC CIDR: 10.40.0.0/16
```

Route Table에 다음 경로를 추가할 수 있다.

```text
10.40.0.0/16 → pcx-xxxxxxxx
```

의미:

```text
목적지가 10.40.0.0/16이면
VPC Peering Connection으로 전달한다.
```

반대편 VPC에도 응답 경로가 필요하다.

```text
VPC A: 10.40.0.0/16 → Peering
VPC B: 10.20.0.0/16 → Peering
```

### 6.6 가장 구체적인 경로 우선

AWS 라우팅은 Longest Prefix Match를 사용한다.

```text
0.0.0.0/0       → IGW
10.40.0.0/16    → Peering A
10.40.10.0/24   → Peering B
```

목적지가 `10.40.10.20`이면 `/24` 경로가 가장 구체적이므로 Peering B가 선택된다.

규칙 등록 순서가 아니라 CIDR의 구체성이 기준이다.

### 6.7 Route Table 하나를 공유해도 되는가?

가능하다. 연결된 Subnet들이 같은 경로 정책을 사용해야 한다면 단일 Route Table은 합리적이다.

장점:

- 설정 중복 감소
- 운영 복잡도 감소
- 신규 Subnet 연결이 쉬움
- 경로 누락 가능성 감소

단점:

- 모든 연결 Subnet에 같은 경로가 적용됨
- 잘못된 변경의 영향 범위가 커짐
- 보안 등급이 다른 네트워크의 도달 가능성을 분리하기 어려움

Route Table 하나가 무조건 나쁜 것도 아니고, 여러 개가 무조건 좋은 것도 아니다. Subnet별로 필요한 경로가 같은지가 판단 기준이다.

---

## 7. Internet Gateway

Internet Gateway(IGW)는 VPC와 인터넷 사이의 연결 지점이다.

IGW는 VPC에 연결한다.

```text
Internet
↕
IGW
↕
VPC
```

### 7.1 IGW는 방화벽이 아니다

IGW는 인터넷 연결 경로를 제공하지만 세부 포트 허용 정책을 관리하는 방화벽은 아니다.

실제 허용 여부에는 다음 요소가 관여한다.

- Public IPv4 또는 Elastic IP 존재
- Subnet Route Table의 IGW 경로
- Security Group
- Network ACL
- 애플리케이션 수신 상태

### 7.2 Public IPv4와 Private IPv4

EC2에 다음 주소가 있다고 가정한다.

```text
Public IPv4:  3.35.100.20
Private IPv4: 10.20.0.10
```

EC2 운영체제의 ENI에는 일반적으로 Private IP가 설정된다.

```text
eth0 → 10.20.0.10
```

Public IP가 운영체제 NIC에 직접 설정되는 구조가 아니다. AWS가 Public IP와 ENI의 Private IP 간 매핑을 관리하고, IGW가 IPv4 통신에서 1:1 NAT 역할을 수행한다.

```text
3.35.100.20
↕ 1:1 NAT
10.20.0.10
↕
ENI
↕
EC2
```

외부에서 들어오는 흐름:

```text
사용자
→ 목적지 3.35.100.20
→ IGW
→ 목적지 10.20.0.10으로 변환
→ ENI
→ Security Group 검사
→ EC2 애플리케이션
```

응답 흐름:

```text
EC2: 10.20.0.10
→ Subnet Route Table
→ IGW
→ 출발지 3.35.100.20으로 변환
→ 사용자
```

### 7.3 Public IP만 있으면 인터넷 통신이 되는가?

아니다. 일반적으로 다음 조건이 함께 필요하다.

```text
1. VPC에 IGW 연결
2. Subnet Route Table에 0.0.0.0/0 → IGW
3. 리소스에 Public IPv4 또는 Elastic IP 존재
4. Security Group 허용
5. Network ACL 허용
6. 애플리케이션이 포트에서 Listen
```

---

## 8. NAT Gateway

NAT Gateway는 Private Subnet의 리소스가 인터넷으로 연결을 시작할 수 있게 하는 관리형 NAT 서비스다.

```text
Private EC2 / EKS Node
→ NAT Gateway
→ IGW
→ Internet
```

NAT Gateway는 Public Subnet에 생성하며 Elastic IP를 사용한다.

```text
Private IP 여러 개
→ NAT Gateway의 Public IP 하나
→ Internet
```

### 8.1 외부에서 Private 리소스로 접속할 수 있는가?

일반적인 Public NAT Gateway를 통해 인터넷 사용자가 Private 리소스에 신규 연결을 시작할 수는 없다.

```text
Private 리소스 → Internet
가능

Internet → NAT Gateway → Private 리소스 신규 연결
불가능
```

Private 리소스가 먼저 시작한 요청의 응답만 돌아올 수 있다.

### 8.2 IGW의 NAT와 NAT Gateway의 차이

| 구분 | IGW의 Public IPv4 매핑 | NAT Gateway |
|---|---|---|
| 주요 대상 | Public Subnet 리소스 | Private Subnet 리소스 |
| 주소 관계 | Public IP 1개와 Private IP 1개의 매핑 | 다수 Private IP가 NAT Public IP 공유 |
| 외부 신규 연결 | SG 등이 허용하면 가능 | 불가능 |
| 개별 리소스 Public IP | 필요 | 불필요 |
| 배치 | VPC에 연결 | 특정 Public Subnet과 AZ |
| 비용 | IGW 자체 시간당 비용 없음 | 시간 및 데이터 처리 비용 발생 |

### 8.3 NAT Gateway 하나를 두 AZ가 공유하는 경우

NAT Gateway A가 AZ 2a에 하나만 존재한다고 가정한다.

```text
AZ 2a Private Subnet
→ NAT Gateway A
→ Internet

AZ 2c Private Subnet
→ AZ 간 이동
→ NAT Gateway A
→ Internet
```

이 구조는 비용이 적지만 다음 단점이 있다.

- NAT Gateway A 또는 AZ 2a 장애 시 두 Private Subnet의 외부 송신 영향
- AZ 2c 트래픽의 교차 AZ 이동
- 외부 송신 경로 관점의 단일 장애점(SPOF)

EKS 내부 Pod 통신이 모두 즉시 중단되는 것은 아니지만 다음 기능에 영향이 생길 수 있다.

- ECR Image Pull
- Bedrock API 호출
- CloudWatch Logs 전송
- 공개 AWS API 접근
- 새 Node 초기화

### 8.4 고가용성 NAT 구조

운영형 구조에서는 AZ마다 NAT Gateway를 둘 수 있다.

```text
Private Subnet A
→ Private Route Table A
→ NAT Gateway A

Private Subnet C
→ Private Route Table C
→ NAT Gateway C
```

이 경우 Private Route Table도 분리해야 한다. Route Table 하나에서 같은 `0.0.0.0/0` 목적지를 AZ에 따라 서로 다른 NAT Gateway로 보낼 수 없기 때문이다.

개발 환경의 비용 절충:

```text
NAT Gateway 1개
Private Route Table 1개 또는 동일 NAT를 가리키는 2개
```

운영 환경의 가용성 우선:

```text
NAT Gateway 2개
Private Route Table 2개
각 Subnet은 같은 AZ의 NAT 사용
```

---

## 9. Security Group

Security Group(SG)은 ENI에 연결되는 상태 저장 방식(stateful)의 가상 방화벽이다.

```text
Internet
→ IGW
→ ENI
→ Security Group 검사
→ EC2 또는 ALB
```

### 9.1 Route Table과 차이

```text
Route Table
= 목적지까지 갈 경로가 존재하는가?

Security Group
= 해당 ENI가 이 통신을 허용하는가?
```

가능한 조합:

```text
Route 있음 + SG 허용 = 통신 가능
Route 있음 + SG 차단 = 통신 불가
Route 없음 + SG 허용 = 통신 불가
```

SG는 허용 규칙을 정의하며 상태를 추적한다. 허용된 인바운드 요청에 대한 응답은 별도 인바운드 규칙 없이 반환될 수 있다.

### 9.2 ALB와 애플리케이션 SG

```text
ALB Security Group
Inbound:
443 ← Internet

Application Security Group
Inbound:
3000 ← ALB Security Group
```

이렇게 구성하면 인터넷은 ALB에만 접근하고, 애플리케이션은 ALB에서 온 트래픽만 받는다.

---

## 10. Application Load Balancer

Application Load Balancer(ALB)는 HTTP/HTTPS를 이해하는 Layer 7 역방향 프록시(reverse proxy)다.

ALB는 AWS 관리형 서비스이면서 특정 VPC 및 Subnet에 연결되어 동작한다.

```text
AWS 관리형 서비스
= 서버 운영, 확장, 장애 처리를 AWS가 담당

VPC 연결 리소스
= 사용자의 Subnet, ENI, Private IP, SG를 통해 통신
```

### 10.1 ALB와 IGW의 관계

ALB가 IGW 하위에 있는 것은 아니다.

```text
VPC
├─ IGW
└─ ALB
```

Internet-facing ALB가 외부와 통신할 때 IGW를 경유한다.

Internal ALB는 Private IP만 사용하므로 인터넷 진입에 IGW를 사용하지 않는다.

### 10.2 ALB의 VPC 연결

Internet-facing ALB는 보통 서로 다른 두 AZ의 Public Subnet을 선택한다.

```text
ALB
├─ AZ 2a Public Subnet의 ALB ENI
└─ AZ 2c Public Subnet의 ALB ENI
```

ALB에는 AWS가 관리하는 DNS 이름이 제공된다.

```text
gameops-alb-123.ap-northeast-2.elb.amazonaws.com
```

일반 ALB의 Public IP는 고정 주소로 직접 관리하는 대상이 아니다. IP가 변경될 수 있으므로 Route 53 Alias 등을 통해 ALB DNS를 사용한다.

### 10.3 외부 요청 흐름

```text
1. 사용자가 chatbot.example.com 조회
2. Route 53이 ALB 대상으로 응답
3. 사용자가 ALB Public IP로 연결
4. IGW를 통해 ALB ENI에 도착
5. ALB Security Group 검사
6. HTTPS Listener가 연결 수신
7. Listener Rule 평가
8. Target Group 선택
9. 정상 Target으로 요청 전달
```

### 10.4 Listener와 Rule

예:

```text
Listener
Protocol: HTTPS
Port: 443
Certificate: ACM Certificate
```

규칙:

```text
Host = chatbot.example.com
Path = /*
→ chatbot-web Target Group
```

다중 서비스 예:

```text
/api/*   → API Target Group
/admin/* → Admin Target Group
/*       → Web Target Group
```

ALB가 확인할 수 있는 주요 HTTP 조건:

- Host
- Path
- HTTP Header
- HTTP Method
- Query String
- Source IP

### 10.5 ALB는 단순 NAT가 아니다

ALB는 클라이언트 연결을 받은 뒤 Target과 별도의 연결을 만든다.

```text
연결 1: 사용자 ↔ ALB
연결 2: ALB ↔ Target
```

즉, 기존 패킷의 목적지만 바꾸는 단순 포워더가 아니라 HTTP 역방향 프록시다.

HTTPS를 ALB에서 종료하면:

```text
사용자 → HTTPS 443 → ALB
ALB → HTTP 3000 → chatbot-web
```

원래 사용자 정보는 HTTP Header로 Target에 전달된다.

```text
X-Forwarded-For
X-Forwarded-Proto
X-Forwarded-Port
```

### 10.6 Target Group

Target Group은 ALB가 요청을 전달할 대상 집합이다.

```text
chatbot-web Target Group
├─ Target A
└─ Target B
```

ALB는 Health Check에 성공한 Target에만 요청을 보낸다.

```text
GET /api/health
```

EKS에서는 Target을 두 방식으로 등록할 수 있다.

Instance Target:

```text
ALB
→ EKS Node의 NodePort
→ Service
→ Pod
```

IP Target:

```text
ALB
→ Pod IP
```

현재 프로젝트는 `chatbot-web` Pod를 IP Target으로 연결하는 방식을 고려할 수 있다.

`chatbot-api`는 외부 ALB Target으로 등록하지 않고 ClusterIP Service를 통해 내부에서만 호출한다.

### 10.7 ALB를 DB 앞에 두면 안 되는 이유

ALB는 HTTP/HTTPS를 이해하지만 MySQL/PostgreSQL 프로토콜이나 SQL 문장을 해석하지 못한다.

따라서 다음 분기는 불가능하다.

```text
SELECT → DB1
INSERT → DB2
```

DB 읽기/쓰기 분리는 다음 계층에서 처리한다.

- 애플리케이션의 Reader/Writer Connection Pool
- Aurora Writer/Reader Endpoint
- RDS Proxy
- ProxySQL, Pgpool-II 같은 DB 전용 Proxy

DB Failover는 단순 Load Balancing과 다르다.

```text
Application
→ 하나의 논리적 Writer Endpoint
→ 현재 Primary DB

Primary 장애
→ Standby 승격
→ Endpoint 전환
→ Application 재연결
```

---

## 11. 주요 패킷 흐름

### 11.1 VPC 내부 Subnet 간 통신

```text
EKS Node A: 10.20.10.15
→ Route Table의 10.20.0.0/16 local
→ EKS Node C: 10.20.11.20
```

SG와 NACL이 허용되어야 한다.

### 11.2 Public EC2에서 인터넷으로

```text
EC2 Private IP
→ Subnet Route Table
→ 0.0.0.0/0 → IGW
→ Public IP로 변환
→ Internet
```

### 11.3 인터넷에서 Public EC2로

```text
Internet
→ EC2 Public IP
→ IGW의 Public/Private IP 매핑
→ EC2 ENI Private IP
→ SG 검사
→ EC2 애플리케이션
```

### 11.4 Private EKS Node에서 인터넷으로

```text
EKS Node
→ Private Route Table
→ NAT Gateway
→ IGW
→ Internet
```

### 11.5 인터넷에서 ALB를 통해 EKS로

```text
사용자
→ Route 53
→ ALB Public DNS/IP
→ IGW
→ ALB ENI
→ ALB SG
→ HTTPS Listener
→ Listener Rule
→ Target Group
→ chatbot-web Pod
```

### 11.6 chatbot-web에서 chatbot-api로

```text
chatbot-web Pod
→ chatbot-api ClusterIP Service
→ chatbot-api Pod
```

이 통신에는 외부 ALB나 IGW가 필요하지 않다.

---

## 12. 이 프로젝트에서 Subnet이 4개인 이유

```text
Public Subnet 2개
→ ALB를 서로 다른 AZ에 연결

Private Subnet 2개
→ EKS Node와 Pod를 서로 다른 AZ에 분산
```

EKS Node가 반드시 두 대여야 해서 Subnet을 두 개 만드는 것은 아니다.

정확한 목적은 다음과 같다.

```text
두 AZ에 리소스를 배치하려면
각 AZ에 별도 Subnet이 필요하다.
```

Subnet 하나는 두 AZ에 걸칠 수 없기 때문이다.

다중 AZ를 사용하더라도 다음 요소가 추가로 필요하다.

- Node의 실제 AZ 분산
- Pod Replica 2개 이상
- Topology Spread Constraints 또는 Pod Anti-Affinity
- PodDisruptionBudget
- ALB의 다중 AZ 연결

Subnet만 두 개 만들었다고 애플리케이션 고가용성이 자동 완성되는 것은 아니다.

---

## 13. 현재 개발 환경의 Route Table과 NAT 판단

현재 Terraform 설정은 다음과 같다.

```text
Public Subnet:        2개
Private Subnet:       2개
Public Route Table:   1개
Private Route Table:  2개
NAT Gateway:          1개
```

Private Route Table 두 개가 같은 NAT Gateway 하나를 가리킨다.

```text
Private Subnet A → Private RT A ─┐
                                 ├→ NAT Gateway A
Private Subnet C → Private RT C ─┘
```

기능적으로 문제는 없지만 개발 환경에서는 다음처럼 단순화할 수 있다.

```text
Private Subnet A ─┐
                  ├→ Private Route Table 1개 → NAT Gateway 1개
Private Subnet C ─┘
```

고가용성 운영 구조에서는 다음 구성이 적절하다.

```text
Private Subnet A → Private RT A → NAT Gateway A
Private Subnet C → Private RT C → NAT Gateway C
```

판단 기준:

```text
dev
→ 비용과 단순성 우선
→ NAT 1개

prod
→ AZ 장애 격리 우선
→ AZ별 NAT
```

---

## 14. 자주 헷갈리는 포인트 교정

### 오해 1: VPC와 Subnet 중 무엇이 네트워크인가?

둘 다 네트워크 개념이지만 범위가 다르다.

```text
VPC
= 전체 사설 네트워크와 라우팅 경계

Subnet
= VPC 내부의 실제 IP 하위 네트워크
```

### 오해 2: AZ는 서울과 부산 같은 지역인가?

아니다.

```text
Region
= 서울 같은 지리적 서비스 지역

AZ
= 서울 Region 내부의 장애 격리 인프라 구역
```

### 오해 3: Subnet 하나를 여러 AZ에서 사용할 수 있는가?

불가능하다. Subnet은 정확히 하나의 AZ에 속한다.

### 오해 4: Route Table은 Subnet을 위해 존재하는가?

Route Table은 VPC 소속 리소스다. Subnet이 Route Table을 연결하여 사용한다.

### 오해 5: Route Table은 외부 송신만 제어하는가?

Route Table은 목적지별 다음 경로를 결정한다. 단순히 외부 송신 전용은 아니다.

다만 일반적인 Subnet Route Table을 인바운드 방화벽처럼 이해하면 안 된다. 접근 허용과 차단은 SG와 NACL이 담당한다.

### 오해 6: `local`이 있으면 VPC 내부 통신이 무조건 되는가?

라우팅은 가능하지만 SG, NACL, 운영체제 방화벽 등이 차단할 수 있다.

### 오해 7: Public IP는 EC2 NIC에 직접 설정되는가?

일반적으로 EC2 ENI에는 Private IP가 설정되고 AWS가 Public IP와 Private IP의 매핑을 관리한다.

### 오해 8: IGW는 단순 라우터인가?

IGW는 VPC와 인터넷의 연결을 제공하며 IPv4 Public IP 통신에서는 Public/Private IP 사이의 1:1 NAT 역할도 수행한다.

### 오해 9: ALB는 IGW의 하위 컴포넌트인가?

아니다. 둘 다 VPC와 연결된 독립 컴포넌트다. Internet-facing ALB가 외부와 통신할 때 IGW 경로를 이용한다.

### 오해 10: ALB는 패킷 목적지만 바꾸는가?

아니다. ALB는 HTTP 요청을 직접 받고 Target에 별도의 연결을 만드는 Layer 7 Reverse Proxy다.

### 오해 11: ALB로 DB 쿼리를 분기할 수 있는가?

불가능하다. ALB는 SQL 프로토콜과 `SELECT`, `INSERT`를 해석하지 못한다.

### 오해 12: DB 두 대에 트래픽을 분산하면 Failover인가?

아니다.

```text
Load Balancing
= 부하 분산

Read Scaling
= 읽기 처리량 확장

Failover
= Primary 장애 시 Standby 승격과 Endpoint 전환
```

---

## 15. 한 문장 요약

```text
VPC
= AWS 안의 전체 사설 네트워크 경계

Subnet
= 특정 AZ에 존재하는 실제 IP 하위 네트워크

Route Table
= Subnet이 사용할 목적지별 다음 경로

IGW
= VPC와 인터넷의 연결 지점

NAT Gateway
= Private 리소스가 외부 연결을 시작하게 하는 출구

ALB
= 외부 HTTP/HTTPS 요청을 받아 정상 애플리케이션 Target에 분산하는 Reverse Proxy

Security Group
= ENI 단위로 통신을 허용하는 Stateful 방화벽
```

우리 프로젝트의 핵심 흐름:

```text
Internet
→ IGW
→ Public Subnet의 ALB
→ Private Subnet의 chatbot-web
→ ClusterIP를 통한 chatbot-api
→ Bedrock
```

Private Subnet의 외부 송신:

```text
EKS Node/Pod
→ Private Route Table
→ NAT Gateway
→ IGW
→ AWS Public Endpoint 또는 Internet
```

---

## 16. AWS 공식 참고 자료

개념이나 서비스 동작이 변경될 가능성이 있으므로 실제 설계 전에는 다음 공식 문서를 다시 확인한다.

- [VPC와 Subnet](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html)
- [Route Table](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [NAT Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [Security Group](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [ALB Listener](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)
- [ALB Target Group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [EKS의 ALB Ingress](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)
