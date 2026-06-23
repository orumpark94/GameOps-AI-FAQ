import type { ChatRequest, ChatResponse } from "../types/chat";

type ErrorPayload = {
  message?: string;
};

export async function requestChatAnswer(request: ChatRequest): Promise<ChatResponse> {
  const response = await fetch("/api/chat", {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify(request)
  });

  const payload = (await response.json()) as ChatResponse | ErrorPayload;

  if (!response.ok) {
    throw new Error("message" in payload && payload.message ? payload.message : "질문 처리 중 오류가 발생했습니다.");
  }

  return payload as ChatResponse;
}
