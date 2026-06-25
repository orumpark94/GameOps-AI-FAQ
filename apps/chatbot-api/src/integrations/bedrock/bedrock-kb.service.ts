import {
  BedrockAgentRuntimeClient,
  RetrieveCommand
} from "@aws-sdk/client-bedrock-agent-runtime";
import {
  BedrockRuntimeClient,
  ConverseCommand
} from "@aws-sdk/client-bedrock-runtime";
import { z } from "zod";
import type { AppConfig } from "../../config/env.js";
import { getCategoryPolicy } from "../../modules/chat/category-policy.js";
import type {
  ChatRequest,
  ChatResponse,
  ChatSource,
  RagService
} from "../../modules/chat/chat.types.js";
import { QueryRewriterService } from "./query-rewriter.service.js";

const NUMBER_OF_RESULTS = 5;
const generatedAnswerSchema = z.discriminatedUnion("status", [
  z.object({
    status: z.literal("answered"),
    answer: z.string().trim().min(1).max(3000)
  }),
  z.object({
    status: z.literal("not_found"),
    answer: z.string().trim().max(3000).optional()
  })
]);

export class BedrockKnowledgeBaseService implements RagService {
  private readonly knowledgeBaseClient: BedrockAgentRuntimeClient;
  private readonly modelClient: BedrockRuntimeClient;
  private readonly queryRewriter: QueryRewriterService;

  constructor(private readonly config: AppConfig) {
    this.knowledgeBaseClient = new BedrockAgentRuntimeClient({ region: config.awsRegion });
    this.modelClient = new BedrockRuntimeClient({ region: config.awsRegion });
    this.queryRewriter = new QueryRewriterService(this.modelClient, config.modelArn);
  }

  async answer(input: ChatRequest): Promise<ChatResponse> {
    const searchQuery = await this.queryRewriter.rewrite({
      category: input.category,
      question: input.question,
      history: input.history
    });

    const retrievalResult = await this.knowledgeBaseClient.send(
      new RetrieveCommand({
        knowledgeBaseId: this.config.knowledgeBaseId,
        retrievalQuery: {
          text: searchQuery
        },
        retrievalConfiguration: {
          vectorSearchConfiguration: {
            numberOfResults: NUMBER_OF_RESULTS,
            filter: {
              equals: {
                key: "category",
                value: input.category
              }
            }
          }
        }
      })
    );

    const topScore = retrievalResult.retrievalResults?.[0]?.score;

    if (topScore === undefined || topScore < this.config.retrievalScoreThreshold) {
      return this.createHandoffResponse();
    }

    const topResult = retrievalResult.retrievalResults?.[0];
    const documentText = topResult?.content?.text?.trim();

    if (!topResult || !documentText) {
      return this.createHandoffResponse();
    }

    const source = this.toSource(topResult.location?.s3Location?.uri);
    const context = `<document id="1" source="${source.title}">\n${documentText}\n</document>`;

    const result = await this.modelClient.send(
      new ConverseCommand({
        modelId: this.config.modelArn,
        system: [
          {
            text: [
              getCategoryPolicy(input.category),
              "",
              "제공된 문서에 질문의 답이 없으면 새로운 답을 만들지 말고 답변할 수 없다고 말하세요.",
              "문서에 없는 기간, 금액, 보상, 처리 결과를 추가하지 마세요.",
              "문서만으로 답변할 수 있으면 status를 answered로 지정하세요.",
              "문서만으로 답변할 수 없으면 status를 not_found로 지정하세요.",
              "설명이나 Markdown 없이 JSON 객체만 반환하세요.",
              '반환 형식: {"status":"answered","answer":"문서 기반 답변"} 또는 {"status":"not_found"}'
            ].join("\n")
          }
        ],
        messages: [
          {
            role: "user",
            content: [
              {
                text: [
                  `[문의유형: ${input.categoryLabel}]`,
                  "",
                  "참고 문서:",
                  context,
                  "",
                  `검색용 질문: ${searchQuery}`,
                  `사용자 질문: ${input.question}`
                ].join("\n")
              }
            ]
          }
        ],
        inferenceConfig: {
          maxTokens: 800,
          temperature: 0,
          topP: 0.9
        }
      })
    );

    const outputText = result.output?.message?.content
      ?.map((content) => ("text" in content ? content.text : undefined))
      .filter((text): text is string => Boolean(text))
      .join("")
      .trim();

    if (!outputText) {
      return this.createHandoffResponse();
    }

    const generatedAnswer = this.parseGeneratedAnswer(outputText);

    if (!generatedAnswer || generatedAnswer.status === "not_found") {
      return this.createHandoffResponse();
    }

    return {
      answer: generatedAnswer.answer,
      sources: [source]
    };
  }

  private createHandoffResponse(): ChatResponse {
    return {
      answer: [
        "사용자님의 질문에 적절한 답변이 없습니다.",
        `자세한 사항이 궁금하시다면 ${this.config.customerSupportEmail}으로 메일 부탁드립니다.`
      ].join(" "),
      sources: []
    };
  }

  private toSource(uri?: string): ChatSource {
    return {
      title: uri?.split("/").pop() ?? "unknown",
      uri
    };
  }

  private parseGeneratedAnswer(text: string) {
    try {
      const fencedJson = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
      const firstBrace = text.indexOf("{");
      const lastBrace = text.lastIndexOf("}");
      const candidate = fencedJson?.[1] ??
        (firstBrace >= 0 && lastBrace > firstBrace ? text.slice(firstBrace, lastBrace + 1) : text);

      return generatedAnswerSchema.parse(JSON.parse(candidate.trim()));
    } catch {
      return null;
    }
  }
}
