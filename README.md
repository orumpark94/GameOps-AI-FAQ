# GameOps-AI-FAQ
게임 FAQ, 공지사항, 패치노트, 운영정책 문서를 기반으로 사용자의 질문에 답변하는 Amazon Bedrock 기반 RAG 챗봇 시스템을 AWS EKS 위에 구축한다.

목표
게임 FAQ, 공지사항, 패치노트, 운영정책 문서를 기반으로 사용자의 질문에 답변하는 Amazon Bedrock 기반 RAG 챗봇 시스템을 AWS EKS 위에 구축한다.
인프라는 Terraform으로 관리하고, GitHub Actions를 통해 인프라 배포와 애플리케이션 배포를 자동화한다.

챗봇 시스템 구축 토이프로젝트 설계 보고서
1. 프로젝트 개요

본 프로젝트는 AWS 기반으로 게임 FAQ 챗봇 시스템을 구축하는 토이프로젝트이다.

Bedrock Knowledge Bases는 S3에 저장된 FAQ/공지/운영정책 문서를 데이터 소스로 사용한다.
문서 동기화 과정에서 Bedrock Knowledge Bases는 문서를 chunking하고 embedding을 생성한 뒤,
S3 Vectors에 벡터 인덱스를 저장한다.

사용자 질문이 들어오면 chatbot-api는 Bedrock Knowledge Bases의 RetrieveAndGenerate 기능을 호출한다.
Bedrock Knowledge Bases는 S3 Vectors에서 관련 문서를 검색하고,
LLM은 검색된 문서 내용을 근거로 답변을 생성한다.


본 프로젝트의 핵심 목표는 단순 LLM API 호출이 아니라, EKS 기반 서비스 분리, ALB 기반 외부 트래픽 처리, 내부 API 보안 분리, Terraform 기반 IaC, GitHub Actions 기반 배포 자동화, Amazon Bedrock 기반 RAG 구조를 함께 설계하고 구현하는 것이다.

2. 프로젝트 목적
2.1 기능적 목적

본 프로젝트는 게임 고객센터에서 자주 발생하는 FAQ성 문의를 자동 응답하는 챗봇 시스템을 목표로 한다.

주요 문의 유형은 다음과 같다.

@게임문의
@결제문의
@계정문의
@해킹/신고

사용자는 챗봇 화면에서 문의 유형을 먼저 선택하고, 해당 유형에 맞는 질문을 입력한다.

예시:

문의 유형: 계정문의
질문: 비밀번호를 잊어버렸어요.
문의 유형: 결제문의
질문: 결제했는데 아이템이 안 들어왔어요.

시스템은 선택된 문의 유형을 기준으로 검색 범위를 좁혀 더 정확한 FAQ 답변을 제공한다.

2.2 기술적 목적

본 프로젝트를 통해 다음 기술 요소를 학습하고 구현한다.

AWS EKS 기반 컨테이너 서비스 운영
ALB 기반 외부 트래픽 라우팅
EKS 내부 서비스 통신 구조
Terraform 기반 AWS IaC 구성
GitHub Actions 기반 CI/CD 구성
Amazon Bedrock 기반 LLM 연동
Bedrock Knowledge Bases 기반 RAG 구성
S3 기반 FAQ 문서 관리
S3 Vectors 기반 벡터 검색 구조
metadata filter 기반 검색 범위 제한
프롬프트 템플릿 기반 답변 정책 제어
IAM / IRSA 기반 권한 분리

