export type AppConfig = {
  port: number;
  awsRegion: string;
  knowledgeBaseId: string;
  modelArn: string;
  retrievalScoreThreshold: number;
  customerSupportEmail: string;
};

export function loadConfig(): AppConfig {
  const port = Number(process.env.PORT ?? 8080);
  const retrievalScoreThreshold = Number(process.env.BEDROCK_RETRIEVAL_SCORE_THRESHOLD ?? 0.6);
  const knowledgeBaseId = process.env.BEDROCK_KNOWLEDGE_BASE_ID?.trim();
  const modelArn = process.env.BEDROCK_MODEL_ARN?.trim();

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  if (
    !Number.isFinite(retrievalScoreThreshold) ||
    retrievalScoreThreshold < 0 ||
    retrievalScoreThreshold > 1
  ) {
    throw new Error("BEDROCK_RETRIEVAL_SCORE_THRESHOLD must be a number between 0 and 1");
  }

  if (!knowledgeBaseId) {
    throw new Error("BEDROCK_KNOWLEDGE_BASE_ID is required");
  }

  if (!modelArn) {
    throw new Error("BEDROCK_MODEL_ARN is required");
  }

  return {
    port,
    awsRegion: process.env.AWS_REGION ?? "ap-northeast-2",
    knowledgeBaseId,
    modelArn,
    retrievalScoreThreshold,
    customerSupportEmail: process.env.CUSTOMER_SUPPORT_EMAIL ?? "sjpark@hanbitsoft.com"
  };
}
