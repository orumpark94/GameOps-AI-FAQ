import type { ChatResponse } from "../../types/chat";
import { SourceList } from "./SourceList";
import styles from "./chat.module.css";

type ChatAnswerProps = {
  response: ChatResponse;
};

export function ChatAnswer({ response }: ChatAnswerProps) {
  return (
    <div className={styles.answer}>
      {response.answer}
      {response.sources.length > 0 ? <SourceList sources={response.sources} /> : null}
    </div>
  );
}
