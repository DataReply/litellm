data "aws_iam_policy_document" "bedrock_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.task.arn]
    }
  }
}

resource "aws_iam_role" "litellm_bedrock_role" {
  name               = "${local.name}-bedrock-access"
  assume_role_policy = data.aws_iam_policy_document.bedrock_task_assume.json
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name = "${local.name}-bedrock-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_invoke_policy_attach" {
  role       = aws_iam_role.litellm_bedrock_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}

data "aws_iam_policy_document" "task_bedrock_assume" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.litellm_bedrock_role.arn]
  }
}

resource "aws_iam_role_policy" "task_bedrock_assume" {
  name   = "${local.name}-task-bedrock-assume"
  role   = aws_iam_role.task.name
  policy = data.aws_iam_policy_document.task_bedrock_assume.json
}
