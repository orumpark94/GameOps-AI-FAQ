import {
  BedrockRuntimeClient,
  ConverseCommand
} from "@aws-sdk/client-bedrock-runtime";
import { z } from "zod";
import type { Category } from "../../modules/chat/category-policy.js";
import type { ChatHistoryMessage } from "../../modules/chat/chat.types.js";

const queryRewriteResultSchema = z.object({
  relation: z.enum(["follow_up", "new_topic"]),
  standaloneQuery: z.string().trim().min(2).max(1000)
});

type QueryRewriteInput = {
  category: Category;
  question: string;
  history: ChatHistoryMessage[];
};

export class QueryRewriterService {
  constructor(
    private readonly client: BedrockRuntimeClient,
    private readonly modelId: string
  ) {}

  async rewrite(input: QueryRewriteInput): Promise<string> {
    if (input.history.length === 0) {
      return input.question;
    }

    try {
      const history = input.history
        .map((message) => `${message.role === "user" ? "사용자" : "상담봇"}: ${message.content}`)
        .join("\n");

      const result = await this.client.send(
        new ConverseCommand({
          modelId: this.modelId,
          system: [
            {
              text: [
                "당신은 FAQ 검색용 질문 재작성기입니다.",
                "현재 질문이 이전 대화 없이도 이해 가능한 새로운 질문이면 relation을 new_topic으로 지정하세요.",
                "현재 질문이 '그럼', '그거', '얼마나', '왜요'처럼 이전 대화가 있어야 이해되면 relation을 follow_up으로 지정하세요.",
                "new_topic이면 이전 대화 내용을 섞지 말고 현재 질문을 standaloneQuery에 그대로 정리하세요.",
                "follow_up이면 필요한 이전 문맥만 사용해 독립적으로 이해 가능한 검색 질문으로 바꾸세요.",
                "새로운 사실, 답변, 기간, 금액, 해결 방법을 추가하지 마세요.",
                "카테고리를 변경하지 마세요.",
                "설명이나 Markdown 없이 JSON 객체만 반환하세요.",
                '반환 형식: {"relation":"follow_up|new_topic","standaloneQuery":"검색 질문"}'
              ].join("\n")
            }
          ],
          messages: [
            {
              role: "user",
              content: [
                {
                  text: [
                    `카테고리: ${input.category}`,
                    "",
                    "직전 대화:",
                    history,
                    "",
                    `현재 질문: ${input.question}`
                  ].join("\n")
                }
              ]
            }
          ],
          inferenceConfig: {
            maxTokens: 250,
            temperature: 0,
            topP: 0.9
          }
        })
      );

      const text = result.output?.message?.content
        ?.map((content) => ("text" in content ? content.text : undefined))
        .filter((content): content is string => Boolean(content))
        .join("")
        .trim();

      if (!text) {
        return input.question;
      }

      const parsed = queryRewriteResultSchema.safeParse(JSON.parse(this.extractJson(text)));

      if (!parsed.success || parsed.data.relation === "new_topic") {
        return input.question;
      }

      return parsed.data.standaloneQuery;
    } catch {
      return input.question;
    }
  }

  private extractJson(text: string): string {
    const fencedJson = text.match(/```(?:json)?\s*([\s\S]*?)```/i);

    if (fencedJson?.[1]) {
      return fencedJson[1].trim();
    }

    const firstBrace = text.indexOf("{");
    const lastBrace = text.lastIndexOf("}");

    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return text.slice(firstBrace, lastBrace + 1);
    }

    return text;
  }
}
