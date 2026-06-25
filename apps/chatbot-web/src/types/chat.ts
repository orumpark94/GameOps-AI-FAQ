export const categories = [
  { value: "game", label: "게임문의" },
  { value: "payment", label: "결제문의" },
  { value: "account", label: "계정문의" },
  { value: "security_report", label: "해킹/신고" }
] as const;

export type Category = (typeof categories)[number];
export type CategoryValue = Category["value"];

export type ChatHistoryMessage = {
  role: "user" | "assistant";
  content: string;
};

export type ChatRequest = {
  category: CategoryValue;
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

export type ChatMessage = ChatHistoryMessage & {
  id: string;
  sources?: ChatSource[];
};
