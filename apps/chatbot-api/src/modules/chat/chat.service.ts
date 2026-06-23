import { categories } from "./category-policy.js";
import type { ChatRequest, ChatResponse, RagService } from "./chat.types.js";

export class ChatService {
  constructor(private readonly ragService: RagService) {}

  getCategories() {
    return Object.entries(categories).map(([value, label]) => ({ value, label }));
  }

  async answer(input: ChatRequest): Promise<ChatResponse> {
    return this.ragService.answer(input);
  }
}
