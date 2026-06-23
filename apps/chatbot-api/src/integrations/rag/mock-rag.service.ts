import { categories } from "../../modules/chat/category-policy.js";
import type { ChatRequest, ChatResponse, RagService } from "../../modules/chat/chat.types.js";

export class MockRagService implements RagService {
  async answer(input: ChatRequest): Promise<ChatResponse> {
    return {
      answer: [
        `[${categories[input.category]}] 문의로 접수된 질문입니다.`,
        "현재는 mock RAG 응답입니다.",
        "EKS 통합 단계에서 Amazon Bedrock Knowledge Bases RetrieveAndGenerate 호출로 교체됩니다.",
        "",
        `질문: ${input.question}`,
        "",
        "참고 문서: mock-faq.md"
      ].join("\n"),
      sources: [
        {
          title: "mock-faq.md",
          uri: "s3://gameops-chatbot-kb/dev/mock-faq.md"
        }
      ]
    };
  }
}
