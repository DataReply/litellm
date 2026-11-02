# AgentCore branded-document renderer

This example configures LiteLLM Proxy to use a project-scoped Bedrock AgentCore MCP Gateway target that renders Markdown into a branded PDF. LiteLLM signs every MCP request with SigV4 and assumes a dedicated invocation role; it does not store AWS access keys.

The corresponding renderer Lambda returns a short-lived S3 download URL after a successful `render_data_reply_pdf` call. The MCP Gateway and Lambda infrastructure are managed separately.

## Prerequisites

The LiteLLM workload role must be allowed to assume `AGENTCORE_DOCUMENT_RENDERER_ROLE_ARN`. That role needs `bedrock-agentcore:InvokeGateway` only for the target project's MCP Gateway. The Gateway's Cedar policy must allow the same assumed role. The role must not have direct `lambda:InvokeFunction` or access to other project gateways.

Set the following environment variables before starting the proxy:

```bash
export AGENTCORE_DOCUMENT_RENDERER_MCP_URL='https://...'
export AGENTCORE_DOCUMENT_RENDERER_ROLE_ARN='arn:aws:iam::123456789012:role/...'
export AWS_REGION='eu-west-1'
export LITELLM_MASTER_KEY='...'
```

Start LiteLLM with the accompanying configuration:

```bash
litellm --config cookbook/litellm_proxy_server/mcp/agentcore_document_renderer.yaml
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

LiteLLM access control determines which users and teams can discover and call the MCP server. IAM limits LiteLLM's assumed role to one project Gateway. Cedar limits the allowed Gateway target. The renderer Lambda writes only to its artifact S3 prefix and returns a short-lived presigned URL.

Do not configure static `aws_access_key_id` or `aws_secret_access_key` values in LiteLLM. `aws_role_name` ensures LiteLLM obtains short-lived credentials with STS. Do not expose the renderer with a Lambda Function URL or API Gateway; use the AgentCore MCP Gateway endpoint.
