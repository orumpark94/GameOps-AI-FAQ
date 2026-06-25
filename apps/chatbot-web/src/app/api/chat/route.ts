import { NextResponse } from "next/server";

const apiBaseUrl = process.env.CHATBOT_API_BASE_URL ?? "http://localhost:8080";
const CHATBOT_API_TIMEOUT_MS = 60_000;

export async function POST(request: Request) {
  try {
    const body = await request.json();

    const response = await fetch(`${apiBaseUrl}/chat`, {
      method: "POST",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify(body),
      cache: "no-store",
      signal: AbortSignal.timeout(CHATBOT_API_TIMEOUT_MS)
    });

    const payload = await response.json().catch(() => ({
      message: "답변 생성 서비스에서 올바른 응답을 받지 못했습니다."
    }));

    return NextResponse.json(payload, { status: response.status });
  } catch (error) {
    const isTimeout =
      error instanceof Error &&
      (error.name === "TimeoutError" || error.name === "AbortError");

    return NextResponse.json(
      {
        message: isTimeout
          ? "답변 생성 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요."
          : "답변 생성 서비스에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."
      },
      { status: isTimeout ? 504 : 502 }
    );
  }
}
