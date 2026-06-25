import cors from "@fastify/cors";
import Fastify from "fastify";
import type { AppConfig } from "./config/env.js";
import { registerChatRoutes } from "./modules/chat/chat.routes.js";

export function buildApp(config: AppConfig) {
  const app = Fastify({
    logger: true
  });

  void app.register(cors, {
    origin: false
  });

  app.get("/health", async () => ({
    status: "ok",
    service: "chatbot-api",
    ragBackend: "bedrock-knowledge-base"
  }));

  void app.register(registerChatRoutes, {
    config,
    prefix: ""
  });

  return app;
}
