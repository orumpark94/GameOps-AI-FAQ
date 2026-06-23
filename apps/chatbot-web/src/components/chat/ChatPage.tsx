"use client";

import { FormEvent, useMemo, useState } from "react";
import { requestChatAnswer } from "../../lib/chatApi";
import { categories, type CategoryValue, type ChatResponse } from "../../types/chat";
import { ChatAnswer } from "./ChatAnswer";
import { ChatForm } from "./ChatForm";
import { CategorySelector } from "./CategorySelector";
import styles from "./chat.module.css";

export function ChatPage() {
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
      const answer = await requestChatAnswer({
        category: selectedCategory.value,
        categoryLabel: selectedCategory.label,
        question
      });

      setResponse(answer);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "알 수 없는 오류가 발생했습니다.");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className={styles.page}>
      <div className={styles.shell}>
        <header className={styles.header}>
          <h1>GameOps AI FAQ</h1>
          <p>문의 유형을 선택하고 질문을 입력하면 FAQ 문서 기반 답변을 제공합니다.</p>
        </header>

        <section className={styles.workspace}>
          <aside className={styles.panel}>
            <h2>문의 유형</h2>
            <CategorySelector categories={categories} selected={category} onSelect={setCategory} />
          </aside>

          <section className={styles.panel}>
            <h2>질문</h2>
            <ChatForm
              isLoading={isLoading}
              onQuestionChange={setQuestion}
              onSubmit={submitQuestion}
              question={question}
            />
            {error ? <div className={styles.error}>{error}</div> : null}
            {response ? <ChatAnswer response={response} /> : null}
          </section>
        </section>
      </div>
    </main>
  );
}
