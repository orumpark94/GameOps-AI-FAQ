import {
  BedrockAgentRuntimeClient,
  RetrieveAndGenerateCommand
} from "@aws-sdk/client-bedrock-agent-runtime";
import { categories, getCategoryPolicy, type Category } from "./categories.js";
import type { AppConfig } from "./config.js";

export type ChatRequest = {
  category: Category;
  categoryLabel: string;
  question: string;
};

export type ChatSource = {
  title: string;
  uri?: string;
};

export type ChatResponse = {
  answer: string;
  sources: ChatSource[];
};

export interface RagService {
  answer(input: ChatRequest): Promise<ChatResponse>;
}

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

export class BedrockKnowledgeBaseService implements RagService {
  private readonly client: BedrockAgentRuntimeClient;

  constructor(private readonly config: AppConfig) {
    if (!config.knowledgeBaseId || !config.modelArn) {
      throw new Error("BEDROCK_KNOWLEDGE_BASE_ID and BEDROCK_MODEL_ARN are required when RAG_PROVIDER=bedrock");
    }

    this.client = new BedrockAgentRuntimeClient({ region: config.awsRegion });
  }

  async answer(input: ChatRequest): Promise<ChatResponse> {
    const command = new RetrieveAndGenerateCommand({
      input: {
        text: [
          getCategoryPolicy(input.category),
          "",
          `[문의유형: ${input.categoryLabel}]`,
          `사용자 질문: ${input.question}`
        ].join("\n")
      },
      retrieveAndGenerateConfiguration: {
        type: "KNOWLEDGE_BASE",
        knowledgeBaseConfiguration: {
          knowledgeBaseId: this.config.knowledgeBaseId,
          modelArn: this.config.modelArn,
          retrievalConfiguration: {
            vectorSearchConfiguration: {
              numberOfResults: 5,
              filter: {
                equals: {
                  key: "category",
                  value: input.category
                }
              }
            }
          }
        }
      }
    });

    const result = await this.client.send(command);
    const citations = result.citations ?? [];
    const sources = citations.flatMap((citation) =>
      (citation.retrievedReferences ?? []).map((reference) => ({
        title: reference.location?.s3Location?.uri?.split("/").pop() ?? "unknown",
        uri: reference.location?.s3Location?.uri
      }))
    );

    return {
      answer: result.output?.text ?? "검색된 문서를 기반으로 답변을 생성하지 못했습니다.",
      sources
    };
  }
}

export function createRagService(config: AppConfig): RagService {
  if (config.ragProvider === "bedrock") {
    return new BedrockKnowledgeBaseService(config);
  }

  return new MockRagService();
}
