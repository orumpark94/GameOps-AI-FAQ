import type { FastifyPluginAsync } from "fastify";
import type { AppConfig } from "../../config/env.js";
import { createRagService } from "../../integrations/rag/rag.factory.js";
import { chatRequestSchema } from "./chat.schema.js";
import { ChatService } from "./chat.service.js";

type ChatRoutesOptions = {
  config: AppConfig;
};

export const registerChatRoutes: FastifyPluginAsync<ChatRoutesOptions> = async (app, options) => {
  const chatService = new ChatService(createRagService(options.config));

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

    const response = await chatService.answer(parsed.data);
    return reply.send(response);
  });
};
