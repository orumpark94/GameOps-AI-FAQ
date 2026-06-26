"use client";

import { FormEvent, useMemo, useState } from "react";
import { requestChatAnswer } from "../../lib/chatApi";
import { createClientId } from "../../lib/createClientId";
import { categories, type CategoryValue, type ChatMessage } from "../../types/chat";
import { ChatAnswer } from "./ChatAnswer";
import { ChatForm } from "./ChatForm";
import { CategorySelector } from "./CategorySelector";
import styles from "./chat.module.css";

export function ChatPage() {
  const [category, setCategory] = useState<CategoryValue>("account");
  const [question, setQuestion] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const selectedCategory = useMemo(
    () => categories.find((item) => item.value === category) ?? categories[0],
    [category]
  );

  async function submitQuestion(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const trimmedQuestion = question.trim();

    if (trimmedQuestion.length < 2) {
      return;
    }

    setError("");
    setIsLoading(true);

    const history = messages.slice(-2).map(({ role, content }) => ({ role, content }));
    const userMessage: ChatMessage = {
      id: createClientId(),
      role: "user",
      content: trimmedQuestion
    };

    setMessages((current) => [...current, userMessage]);
    setQuestion("");

    try {
      const answer = await requestChatAnswer({
        category: selectedCategory.value,
        categoryLabel: selectedCategory.label,
        question: trimmedQuestion,
        history
      });

      setMessages((current) => [
        ...current,
        {
          id: createClientId(),
          role: "assistant",
          content: answer.answer,
          sources: answer.sources
        }
      ]);
    } catch (caught) {
      setMessages((current) => current.filter((message) => message.id !== userMessage.id));
      setQuestion(trimmedQuestion);
      setError(caught instanceof Error ? caught.message : "알 수 없는 오류가 발생했습니다.");
    } finally {
      setIsLoading(false);
    }
  }

  function selectCategory(nextCategory: CategoryValue) {
    if (nextCategory === category || isLoading) {
      return;
    }

    setCategory(nextCategory);
    setMessages([]);
    setQuestion("");
    setError("");
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
            <CategorySelector categories={categories} selected={category} onSelect={selectCategory} />
          </aside>

          <section className={styles.panel}>
            <h2>질문</h2>
            {messages.length > 0 ? (
              <div className={styles.chatHistory}>
                {messages.map((message) =>
                  message.role === "user" ? (
                    <div className={styles.userMessage} key={message.id}>
                      {message.content}
                    </div>
                  ) : (
                    <ChatAnswer
                      answer={message.content}
                      key={message.id}
                      sources={message.sources ?? []}
                    />
                  )
                )}
              </div>
            ) : null}
            <ChatForm
              isLoading={isLoading}
              onQuestionChange={setQuestion}
              onSubmit={submitQuestion}
              question={question}
            />
            {error ? <div className={styles.error}>{error}</div> : null}
          </section>
        </section>
      </div>
    </main>
  );
}
