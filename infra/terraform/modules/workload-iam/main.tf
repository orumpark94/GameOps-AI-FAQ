data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.name_prefix}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${var.name_prefix}-alb-controller-policy"
  policy = file("${path.module}/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "aws_iam_role" "chatbot_api" {
  name               = "${var.name_prefix}-chatbot-api-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
}

data "aws_iam_policy_document" "chatbot_api" {
  statement {
    sid       = "RetrieveKnowledgeBase"
    effect    = "Allow"
    actions   = ["bedrock:Retrieve"]
    resources = [var.knowledge_base_arn]
  }

  statement {
    sid       = "InvokeGenerationModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = var.generation_model_resource_arns
  }
}

resource "aws_iam_role_policy" "chatbot_api" {
  name   = "${var.name_prefix}-chatbot-api-bedrock"
  role   = aws_iam_role.chatbot_api.id
  policy = data.aws_iam_policy_document.chatbot_api.json
}
