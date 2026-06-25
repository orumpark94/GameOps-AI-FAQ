locals {
  document_bucket_name = "${var.name_prefix}-kb-documents-${var.account_id}"
  vector_bucket_name   = "${var.name_prefix}-vectors-${var.account_id}"
  vector_index_name    = "${var.name_prefix}-index"
  embedding_model_arn  = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
}

resource "aws_s3_bucket" "documents" {
  bucket        = local.document_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = local.vector_bucket_name
  force_destroy      = true
}

resource "aws_s3vectors_index" "this" {
  index_name         = local.vector_index_name
  vector_bucket_name = aws_s3vectors_vector_bucket.this.vector_bucket_name
  data_type          = "float32"
  dimension          = var.embedding_dimensions
  distance_metric    = "cosine"

  metadata_configuration {
    non_filterable_metadata_keys = ["AMAZON_BEDROCK_TEXT", "AMAZON_BEDROCK_METADATA"]
  }
}

data "aws_iam_policy_document" "bedrock_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${var.aws_region}:${var.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "bedrock" {
  name               = "${var.name_prefix}-bedrock-kb-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_assume_role.json
}

data "aws_iam_policy_document" "bedrock" {
  statement {
    sid       = "ReadKnowledgeDocuments"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.documents.arn]
  }

  statement {
    sid       = "ReadKnowledgeDocumentObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents.arn}/${var.document_prefix}*"]
  }

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.embedding_model_arn]
  }

  statement {
    sid     = "UseS3Vectors"
    effect  = "Allow"
    actions = ["s3vectors:*"]
    resources = [
      aws_s3vectors_vector_bucket.this.vector_bucket_arn,
      aws_s3vectors_index.this.index_arn
    ]
  }
}

resource "aws_iam_role_policy" "bedrock" {
  name   = "${var.name_prefix}-bedrock-kb-policy"
  role   = aws_iam_role.bedrock.id
  policy = data.aws_iam_policy_document.bedrock.json
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name        = "${var.name_prefix}-kb"
  description = "Game FAQ, notices, patch notes, and operation policies."
  role_arn    = aws_iam_role.bedrock.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"

    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.this.index_arn
    }
  }

  depends_on = [aws_iam_role_policy.bedrock]
}

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "${var.name_prefix}-s3-documents"
  data_deletion_policy = "DELETE"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn         = aws_s3_bucket.documents.arn
      inclusion_prefixes = [var.document_prefix]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = var.chunk_max_tokens
        overlap_percentage = var.chunk_overlap_percentage
      }
    }
  }
}
