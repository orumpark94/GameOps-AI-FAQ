# RAG 답변 안전성과 대화 처리

현재 API는 `RetrieveAndGenerate`가 아니라 검색과 생성을 분리합니다. 각 단계의 입력, 필터, 임계값, 프롬프트를 애플리케이션이 통제하기 위한 선택입니다.

## 처리 흐름

```text
질문 + 최근 대화 최대 2개 + 카테고리
→ 대화 이력이 있으면 Nova Micro로 독립 검색 질의 재작성
→ Bedrock Knowledge Base Retrieve (상위 5개, category filter)
→ 최고 검색 점수 확인
→ 임계값 미만이면 상담 채널 안내
→ 통과하면 최고 점수 문서 조각 1개와 카테고리 정책으로 Nova Micro 답변 생성
→ 답변과 출처 반환
```

## 검색 정확도 제어

사용자는 게임문의(`game`), 결제문의(`payment`), 계정문의(`account`), 해킹/신고(`security_report`) 중 하나를 선택합니다. API는 영문 식별자를 Zod로 검증하고 Retrieval Filter의 `category` 조건으로 사용합니다. 각 FAQ의 `.metadata.json`에 같은 식별자가 있어야 검색됩니다.

대화 이력이 없으면 사용자 질문을 그대로 검색합니다. 이력이 있으면 “그럼 어떻게 해야 해?” 같은 후속 질문을 최근 메시지 최대 2개와 합쳐 독립적인 검색어로 재작성합니다. 재작성 호출 또는 JSON 파싱이 실패하면 원래 질문으로 검색하는 Fallback이 구현되어 있습니다.

검색 API에는 최대 5개 결과를 요청하지만 현재 답변 생성에는 최고 점수 결과 1개만 전달합니다. 따라서 여러 문서를 종합하는 구조가 아니며, 관련 정보가 여러 FAQ에 분산되면 답변이 불완전할 수 있습니다.

## 근거 없는 답변 방지

기본 검색 점수 임계값은 `0.6`입니다. 결과가 없거나 최고 점수가 임계값보다 낮으면 생성 모델을 호출하지 않고 고객 지원 이메일을 안내합니다. 통과해도 프롬프트는 제공된 참고 문서만 근거로 답하고 확인 불가능한 내용은 추측하지 않도록 제한합니다.

`0.6`은 검증 완료된 보편값이 아닌 초기값입니다. 카테고리별 대표 질문, 정답 문서, Top-k Recall, 점수 분포, 오답률과 답변 거부율로 조정해야 합니다.

## 권한 경계

`chatbot-api`만 EKS Pod Identity로 `bedrock:Retrieve`와 지정 모델의 `bedrock:InvokeModel` 권한을 가집니다. Web ServiceAccount는 Kubernetes 토큰 자동 Mount도 비활성화합니다. Knowledge Base Ingestion, GitHub Actions, 런타임 API 역할은 서로 분리됩니다.

## 현재 한계

- 대화 기록은 요청에 포함되며 서버 영속 저장소가 없습니다.
- 검색·생성 지연, 토큰 사용량, 답변 품질의 중앙 관측성이 없습니다.
- Prompt Injection과 악성 문서에 대한 별도 분류기나 Guardrails가 없습니다.
- CI는 Markdown별 메타데이터 파일 존재 여부와 JSON 문법만 확인합니다. `category` 허용값, 본문과 메타데이터의 일치 여부는 검증하지 않습니다.

운영 단계에서는 평가 데이터셋 기반 회귀 테스트, Bedrock Guardrails 검토, 구조화된 감사 로그, Rate Limit, PII 마스킹, 명시적 Fallback을 추가해야 합니다.
