import type { ChatSource } from "../../types/chat";
import styles from "./chat.module.css";

type SourceListProps = {
  sources: ChatSource[];
};

export function SourceList({ sources }: SourceListProps) {
  return (
    <div className={styles.sources}>
      <h3>출처</h3>
      <ul>
        {sources.map((source, index) => (
          <li key={`${source.title}-${index}`}>
            {source.title}
            {source.uri ? ` (${source.uri})` : ""}
          </li>
        ))}
      </ul>
    </div>
  );
}
