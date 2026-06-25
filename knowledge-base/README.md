# Knowledge Base Documents

이 디렉터리는 Amazon Bedrock Knowledge Bases가 사용하는 FAQ 원본 문서를 Git으로 관리하는 위치다.

## 카테고리

애플리케이션과 Knowledge Base가 공통으로 사용하는 카테고리 식별자는 다음 네 가지다.

| category | 화면 표시 |
|---|---|
| `game` | 게임문의 |
| `payment` | 결제문의 |
| `account` | 계정문의 |
| `security_report` | 해킹/신고 |

```text
knowledge-base/
├─ game/
├─ payment/
├─ account/
└─ security_report/
```

카테고리 디렉터리는 사람이 문서를 관리하기 위한 구조다. 실제 검색 범위 제한은 각 문서의
`category` metadata와 chatbot-api의 metadata filter가 담당한다.

## 문서 작성 단위

하나의 Markdown 파일에는 하나의 FAQ 주제만 작성한다. 여러 카테고리를 한 파일에 섞지 않는다.

각 문서는 같은 이름의 metadata 파일과 함께 관리한다.

```text
password_reset.md
password_reset.md.metadata.json
```

문서 본문은 다음 항목을 기준으로 작성한다.

1. 사용자 질문 예시
2. 답변 기준
3. 사용자가 직접 확인할 순서
4. 고객센터 문의가 필요한 조건
5. 문의 시 필요한 정보
6. 보안 및 안내 주의사항

## Metadata 규칙

```json
{
  "metadataAttributes": {
    "category": "account",
    "category_label": "계정문의",
    "document_type": "faq",
    "topic": "password_reset",
    "tags": ["비밀번호", "로그인", "본인인증"],
    "handoff_required": false
  }
}
```

- `category`: chatbot-api가 검색 필터에 사용하는 값이다.
- `category_label`: 사용자 화면에 표시되는 한글 이름이다.
- `document_type`: 현재 문서는 모두 `faq`를 사용한다.
- `topic`: FAQ 주제를 구분하는 고유한 영문 식별자다.
- `tags`: 사용자가 자주 입력하는 핵심 표현이다.
- `handoff_required`: 대부분의 상황에서 고객센터 확인이 필요한지를 나타낸다.

Metadata는 문서 단위로 적용되며 해당 문서에서 생성된 모든 chunk에 전달된다.

## 업로드

Infrastructure 생성 후 `knowledge_base_document_bucket` output을 사용해 `dev/` prefix에 업로드한다.

```powershell
$bucket = terraform output -raw knowledge_base_document_bucket
aws s3 sync knowledge-base "s3://$bucket/dev/" --delete
```

문서를 업로드한 뒤에는 Bedrock Knowledge Base Data Source의 ingestion job을 별도로 실행해야 한다.
