import type { FormEvent } from "react";
import styles from "./chat.module.css";

type ChatFormProps = {
  question: string;
  isLoading: boolean;
  onQuestionChange: (question: string) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
};

export function ChatForm({ question, isLoading, onQuestionChange, onSubmit }: ChatFormProps) {
  return (
    <form className={styles.chatForm} onSubmit={onSubmit}>
      <textarea
        className={styles.questionInput}
        onChange={(event) => onQuestionChange(event.target.value)}
        placeholder="질문을 입력해주세요."
        value={question}
      />
      <div className={styles.actions}>
        <button className={styles.submitButton} disabled={isLoading || question.trim().length < 2} type="submit">
          {isLoading ? "답변 생성 중" : "질문하기"}
        </button>
      </div>
    </form>
  );
}
