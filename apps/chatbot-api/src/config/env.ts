export type RagProvider = "mock" | "bedrock";

export type AppConfig = {
  port: number;
  awsRegion: string;
  ragProvider: RagProvider;
  knowledgeBaseId?: string;
  modelArn?: string;
};

export function loadConfig(): AppConfig {
  const ragProvider = (process.env.RAG_PROVIDER ?? "mock") as RagProvider;

  if (!["mock", "bedrock"].includes(ragProvider)) {
    throw new Error("RAG_PROVIDER must be either 'mock' or 'bedrock'");
  }

  return {
    port: Number(process.env.PORT ?? 8080),
    awsRegion: process.env.AWS_REGION ?? "ap-northeast-2",
    ragProvider,
    knowledgeBaseId: process.env.BEDROCK_KNOWLEDGE_BASE_ID,
    modelArn: process.env.BEDROCK_MODEL_ARN
  };
}
