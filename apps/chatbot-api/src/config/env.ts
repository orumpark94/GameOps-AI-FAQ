export type RagProvider = "mock" | "bedrock";

export type AppConfig = {
  port: number;
  awsRegion: string;
  ragProvider: RagProvider;
  knowledgeBaseId?: string;
  modelArn?: string;
  retrievalScoreThreshold: number;
  customerSupportEmail: string;
};

export function loadConfig(): AppConfig {
  const ragProvider = (process.env.RAG_PROVIDER ?? "mock") as RagProvider;
  const retrievalScoreThreshold = Number(process.env.BEDROCK_RETRIEVAL_SCORE_THRESHOLD ?? 0.6);

  if (!["mock", "bedrock"].includes(ragProvider)) {
    throw new Error("RAG_PROVIDER must be either 'mock' or 'bedrock'");
  }

  if (
    !Number.isFinite(retrievalScoreThreshold) ||
    retrievalScoreThreshold < 0 ||
    retrievalScoreThreshold > 1
  ) {
    throw new Error("BEDROCK_RETRIEVAL_SCORE_THRESHOLD must be a number between 0 and 1");
  }

  return {
    port: Number(process.env.PORT ?? 8080),
    awsRegion: process.env.AWS_REGION ?? "ap-northeast-2",
    ragProvider,
    knowledgeBaseId: process.env.BEDROCK_KNOWLEDGE_BASE_ID,
    modelArn: process.env.BEDROCK_MODEL_ARN,
    retrievalScoreThreshold,
    customerSupportEmail: process.env.CUSTOMER_SUPPORT_EMAIL ?? "sjpark@hanbitsoft.com"
  };
}
