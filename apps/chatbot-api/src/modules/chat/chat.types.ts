import type { Category } from "./category-policy.js";

export type ChatHistoryMessage = {
  role: "user" | "assistant";
  content: string;
};

export type ChatRequest = {
  category: Category;
  categoryLabel: string;
  question: string;
  history: ChatHistoryMessage[];
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
