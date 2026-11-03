resource "aws_lambda_function" "document_renderer" {
  count = var.document_renderer_enabled ? 1 : 0

  function_name = "${local.name}-document-renderer"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.document_renderer[0].repository_url}:${var.document_renderer_image_tag}"
  architectures = ["arm64"]
  role          = aws_iam_role.document_renderer_execution[0].arn

  memory_size = var.document_renderer_memory_size
  timeout     = var.document_renderer_timeout_seconds

  ephemeral_storage {
    size = 1024
  }

  environment {
    variables = {
      DOCUMENT_ARTIFACT_BUCKET          = aws_s3_bucket.this.bucket
      DOCUMENT_ARTIFACT_PREFIX          = "document-renderer"
      DOCUMENT_ARTIFACT_URL_TTL_SECONDS = "900"
      DATA_REPLY_TEMPLATE               = "data-reply-gmbh.lambda.latex"
    }
  }

  lifecycle {
    ignore_changes = [image_uri]

    precondition {
      condition     = var.document_renderer_image_tag != ""
      error_message = "document_renderer_image_tag is required when document_renderer_enabled is true."
    }
  }

  tags = local.tags
}

resource "aws_lambda_function_url" "document_renderer" {
  count = var.document_renderer_enabled ? 1 : 0

  function_name      = aws_lambda_function.document_renderer[0].function_name
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "document_renderer_function_url" {
  count = var.document_renderer_enabled ? 1 : 0

  statement_id           = "AllowDocumentRendererFunctionUrlInvocation"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.document_renderer[0].function_name
  principal              = aws_iam_role.document_renderer_invoker[0].arn
  function_url_auth_type = "AWS_IAM"
}
