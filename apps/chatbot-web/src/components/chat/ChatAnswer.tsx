import type { ChatSource } from "../../types/chat";
import { SourceList } from "./SourceList";
import styles from "./chat.module.css";

type ChatAnswerProps = {
  answer: string;
  sources: ChatSource[];
};

export function ChatAnswer({ answer, sources }: ChatAnswerProps) {
  return (
    <div className={styles.answer}>
      {answer}
      {sources.length > 0 ? <SourceList sources={sources} /> : null}
    </div>
  );
}
