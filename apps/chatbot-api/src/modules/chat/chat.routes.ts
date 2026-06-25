import type { FastifyPluginAsync } from "fastify";
import type { AppConfig } from "../../config/env.js";
import { BedrockKnowledgeBaseService } from "../../integrations/bedrock/bedrock-kb.service.js";
import { chatRequestSchema } from "./chat.schema.js";
import { ChatService } from "./chat.service.js";

type ChatRoutesOptions = {
  config: AppConfig;
};

export const registerChatRoutes: FastifyPluginAsync<ChatRoutesOptions> = async (app, options) => {
  const chatService = new ChatService(new BedrockKnowledgeBaseService(options.config));

  app.get("/categories", async () => ({
    categories: chatService.getCategories()
  }));

  app.post("/chat", async (request, reply) => {
    const parsed = chatRequestSchema.safeParse(request.body);

    if (!parsed.success) {
      return reply.status(400).send({
        message: "Invalid chat request",
        issues: parsed.error.issues
      });
    }

    try {
      const response = await chatService.answer(parsed.data);
      return reply.send(response);
    } catch (error) {
      request.log.error({ err: error }, "Failed to process chat request");

      return reply.status(502).send({
        message: "답변 생성 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요."
      });
    }
  });
};
