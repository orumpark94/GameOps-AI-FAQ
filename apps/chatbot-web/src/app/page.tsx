"use client";

import { FormEvent, useMemo, useState } from "react";

const categories = [
  { value: "game", label: "게임문의" },
  { value: "payment", label: "결제문의" },
  { value: "account", label: "계정문의" },
  { value: "security_report", label: "해킹/신고" }
] as const;

type CategoryValue = (typeof categories)[number]["value"];

type ChatSource = {
  title: string;
  uri?: string;
};

type ChatResponse = {
  answer: string;
  sources: ChatSource[];
};

export default function Home() {
  const [category, setCategory] = useState<CategoryValue>("account");
  const [question, setQuestion] = useState("");
  const [response, setResponse] = useState<ChatResponse | null>(null);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const selectedCategory = useMemo(
    () => categories.find((item) => item.value === category) ?? categories[0],
    [category]
  );

  async function submitQuestion(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setResponse(null);
    setIsLoading(true);

    try {
      const result = await fetch("/api/chat", {
        method: "POST",
        headers: {
          "content-type": "application/json"
        },
        body: JSON.stringify({
          category: selectedCategory.value,
          categoryLabel: selectedCategory.label,
          question
        })
      });

      const payload = await result.json();

      if (!result.ok) {
        throw new Error(payload.message ?? "질문 처리 중 오류가 발생했습니다.");
      }

      setResponse(payload);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "알 수 없는 오류가 발생했습니다.");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className="page">
      <div className="shell">
        <header className="header">
          <h1>GameOps AI FAQ</h1>
          <p>문의 유형을 선택하고 질문을 입력하면 FAQ 문서 기반 답변을 제공합니다.</p>
        </header>

        <section className="workspace">
          <aside className="panel">
            <h2>문의 유형</h2>
            <div className="category-list">
              {categories.map((item) => (
                <button
                  className={`category-button ${item.value === category ? "active" : ""}`}
                  key={item.value}
                  onClick={() => setCategory(item.value)}
                  type="button"
                >
                  {item.label}
                </button>
              ))}
            </div>
          </aside>

          <section className="panel">
            <h2>질문</h2>
            <form className="chat-form" onSubmit={submitQuestion}>
              <textarea
                className="question-input"
                onChange={(event) => setQuestion(event.target.value)}
                placeholder="질문을 입력해주세요."
                value={question}
              />
              <div className="actions">
                <button className="submit-button" disabled={isLoading || question.trim().length < 2} type="submit">
                  {isLoading ? "답변 생성 중" : "질문하기"}
                </button>
              </div>
            </form>

            {error ? <div className="error">{error}</div> : null}

            {response ? (
              <div className="answer">
                {response.answer}
                {response.sources.length > 0 ? (
                  <div className="sources">
                    <h3>출처</h3>
                    <ul>
                      {response.sources.map((source, index) => (
                        <li key={`${source.title}-${index}`}>
                          {source.title}
                          {source.uri ? ` (${source.uri})` : ""}
                        </li>
                      ))}
                    </ul>
                  </div>
                ) : null}
              </div>
            ) : null}
          </section>
        </section>
      </div>
    </main>
  );
}
