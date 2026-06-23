import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "GameOps AI FAQ",
  description: "GameOps AI FAQ chatbot"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
