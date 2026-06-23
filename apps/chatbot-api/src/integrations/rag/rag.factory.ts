import type { AppConfig } from "../../config/env.js";
import { BedrockKnowledgeBaseService } from "../bedrock/bedrock-kb.service.js";
import { MockRagService } from "./mock-rag.service.js";
import type { RagService } from "../../modules/chat/chat.types.js";

export function createRagService(config: AppConfig): RagService {
  if (config.ragProvider === "bedrock") {
    return new BedrockKnowledgeBaseService(config);
  }

  return new MockRagService();
}
