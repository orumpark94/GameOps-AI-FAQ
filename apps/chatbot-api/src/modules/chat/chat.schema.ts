import { z } from "zod";
import { isCategory } from "./category-policy.js";

export const chatRequestSchema = z.object({
  category: z.string().refine(isCategory, "Unsupported category"),
  categoryLabel: z.string().min(1).max(30),
  question: z.string().trim().min(2).max(1000)
});
