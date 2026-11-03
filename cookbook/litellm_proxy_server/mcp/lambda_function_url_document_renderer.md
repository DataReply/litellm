# Lambda Function URL document renderer

This example configures LiteLLM Proxy to call a branded-document renderer over a Lambda Function URL. LiteLLM signs every MCP request with SigV4 and assumes a dedicated invocation role; it does not store AWS access keys.

The renderer returns a short-lived S3 download URL after a successful `render_data_reply_pdf` call. The Lambda Function URL and renderer are managed separately.

## Prerequisites

Configure the Lambda Function URL with `AWS_IAM` authorization. The LiteLLM workload role must be allowed to assume `DOCUMENT_RENDERER_ROLE_ARN`. That role needs `lambda:InvokeFunctionUrl` and `lambda:InvokeFunction` only for the target renderer. The Lambda Function URL resource policy must allow the same assumed role. The role must not invoke other functions.

Set the following environment variables before starting the proxy:

```bash
export DOCUMENT_RENDERER_MCP_URL='https://...lambda-url.eu-west-1.on.aws/mcp'
export DOCUMENT_RENDERER_ROLE_ARN='arn:aws:iam::123456789012:role/...'
export DOCUMENT_RENDERER_REGION='eu-west-1'
export LITELLM_MASTER_KEY='...'
```

Start LiteLLM with the accompanying configuration:

```bash
litellm --config cookbook/litellm_proxy_server/mcp/lambda_function_url_document_renderer.yaml
```

## Use through LiteLLM MCP

Use LiteLLM's MCP endpoint for tool discovery and direct tool calls. Restrict the configured MCP server to the LiteLLM teams or keys allowed to render branded documents. Keep `render_data_reply_pdf` approval-gated in clients that support MCP tool approval.

A render request accepts only Markdown and a safe filename stem. The successful response contains a short-lived `download_url`; clients must treat it as sensitive because it authorizes retrieval of the generated document.

```json
{
  "name": "render_data_reply_pdf",
  "arguments": {
    "filename": "quarterly-report",
    "markdown": "---\ntitle: Quarterly Report\n---\n# Summary\n"
  }
}
```

## Security boundaries

LiteLLM access control determines which users and teams can discover and call the MCP server. IAM limits LiteLLM's assumed role to one Lambda Function URL. The renderer Lambda writes only to its artifact S3 prefix and returns a short-lived presigned URL.

Do not configure static `aws_access_key_id` or `aws_secret_access_key` values in LiteLLM. `aws_role_name` ensures LiteLLM obtains short-lived credentials with STS. Do not enable public Function URL access or add API Gateway.
