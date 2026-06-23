import type { Category, CategoryValue } from "../../types/chat";
import styles from "./chat.module.css";

type CategorySelectorProps = {
  categories: readonly Category[];
  selected: CategoryValue;
  onSelect: (category: CategoryValue) => void;
};

export function CategorySelector({ categories, selected, onSelect }: CategorySelectorProps) {
  return (
    <div className={styles.categoryList}>
      {categories.map((item) => (
        <button
          className={`${styles.categoryButton} ${item.value === selected ? styles.activeCategory : ""}`}
          key={item.value}
          onClick={() => onSelect(item.value)}
          type="button"
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}
