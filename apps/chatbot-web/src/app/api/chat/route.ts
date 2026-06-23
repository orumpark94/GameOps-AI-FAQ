import { NextResponse } from "next/server";

const apiBaseUrl = process.env.CHATBOT_API_BASE_URL ?? "http://localhost:8080";

export async function POST(request: Request) {
  const body = await request.json();

  const response = await fetch(`${apiBaseUrl}/chat`, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify(body),
    cache: "no-store"
  });

  const payload = await response.json().catch(() => ({
    message: "chatbot-api returned a non-JSON response"
  }));

  return NextResponse.json(payload, { status: response.status });
}
