import { z } from "zod";
import { isCategory } from "./category-policy.js";

const chatHistoryMessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().trim().min(1).max(2000)
});

export const chatRequestSchema = z.object({
  category: z.string().refine(isCategory, "Unsupported category"),
  categoryLabel: z.string().min(1).max(30),
  question: z.string().trim().min(2).max(1000),
  history: z.array(chatHistoryMessageSchema).max(2).default([])
});
