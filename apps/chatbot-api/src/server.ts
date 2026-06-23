import cors from "@fastify/cors";
import Fastify from "fastify";
import { z } from "zod";
import { categories, isCategory } from "./categories.js";
import { loadConfig } from "./config.js";
import { createRagService } from "./ragService.js";

const config = loadConfig();
const ragService = createRagService(config);

const chatRequestSchema = z.object({
  category: z.string().refine(isCategory, "Unsupported category"),
  categoryLabel: z.string().min(1).max(30),
  question: z.string().trim().min(2).max(1000)
});

const app = Fastify({
  logger: true
});

await app.register(cors, {
  origin: false
});

app.get("/health", async () => ({
  status: "ok",
  service: "chatbot-api",
  ragProvider: config.ragProvider
}));

app.get("/categories", async () => ({
  categories: Object.entries(categories).map(([value, label]) => ({ value, label }))
}));

app.post("/chat", async (request, reply) => {
  const parsed = chatRequestSchema.safeParse(request.body);

  if (!parsed.success) {
    return reply.status(400).send({
      message: "Invalid chat request",
      issues: parsed.error.issues
    });
  }

  const response = await ragService.answer(parsed.data);
  return reply.send(response);
});

try {
  await app.listen({ host: "0.0.0.0", port: config.port });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
