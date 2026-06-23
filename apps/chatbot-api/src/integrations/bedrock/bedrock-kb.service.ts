import {
  BedrockAgentRuntimeClient,
  RetrieveAndGenerateCommand
} from "@aws-sdk/client-bedrock-agent-runtime";
import type { AppConfig } from "../../config/env.js";
import { getCategoryPolicy } from "../../modules/chat/category-policy.js";
import type { ChatRequest, ChatResponse, RagService } from "../../modules/chat/chat.types.js";

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
