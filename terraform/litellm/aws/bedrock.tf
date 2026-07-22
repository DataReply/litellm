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

data "aws_partition" "current" {}

data "aws_caller_identity" "bedrock_current" {}

locals {
  bedrock_cross_region_prefixes = ["global", "us", "eu", "apac", "jp", "au", "us-gov"]

  bedrock_models_by_name = {
    for model in var.bedrock_models : model.model_name => replace(
      replace(
        replace(model.model, "bedrock/converse/", ""),
        "bedrock/invoke/",
        "",
      ),
      "bedrock/",
      "",
    )
  }

  bedrock_inference_profile_sources = {
    for model_name, model_id in local.bedrock_models_by_name : model_name => (
      contains(local.bedrock_cross_region_prefixes, split(model_id, ".")[0]) ?
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.bedrock_current.account_id}:inference-profile/${model_id}" :
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}::foundation-model/${model_id}"
    )
  }

  bedrock_backing_foundation_model_ids = distinct([
    for model_id in values(local.bedrock_models_by_name) : (
      contains(local.bedrock_cross_region_prefixes, split(model_id, ".")[0]) ?
      join(".", slice(split(model_id, "."), 1, length(split(model_id, ".")))) :
      model_id
    )
  ])

  bedrock_source_profile_arns = distinct([
    for model_id in values(local.bedrock_models_by_name) :
    "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.bedrock_current.account_id}:inference-profile/${model_id}"
    if contains(local.bedrock_cross_region_prefixes, split(model_id, ".")[0])
  ])

  bedrock_foundation_model_arns = distinct(flatten([
    for model_id in local.bedrock_backing_foundation_model_ids : [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}::foundation-model/${model_id}",
      "arn:${data.aws_partition.current.partition}:bedrock:::foundation-model/${model_id}",
    ]
  ]))

  bedrock_application_profile_arns = [
    for profile in aws_bedrock_inference_profile.model : profile.arn
  ]

  bedrock_invoke_resources = concat(
    local.bedrock_application_profile_arns,
    local.bedrock_source_profile_arns,
    local.bedrock_foundation_model_arns,
  )
}

resource "aws_bedrock_inference_profile" "model" {
  for_each = local.bedrock_inference_profile_sources

  name = substr(replace("${local.name}-${each.key}", "_", "-"), 0, 64)

  description = substr("LiteLLM application inference profile for ${each.key}", 0, 200)

  model_source {
    copy_from = each.value
  }

  tags = local.tags
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  count = length(local.bedrock_invoke_resources) == 0 ? 0 : 1

  name = "${local.name}-bedrock-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = local.bedrock_invoke_resources
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_invoke_policy_attach" {
  count = length(local.bedrock_invoke_resources) == 0 ? 0 : 1

  role       = aws_iam_role.litellm_bedrock_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy[0].arn
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
