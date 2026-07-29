region = "eu-central-1"
azs    = ["eu-central-1a", "eu-central-1b"]

tenant = "data-reply"
env    = "prod"

acm_certificate_domain_name = "litellm.datareply.de"
route53_zone_id             = "Z0891217221E1PTCMOPWZ"

s3_force_destroy               = false
skip_final_snapshot            = false
db_enable_reader               = false
db_primary_instance_identifier = "data-reply-litellm-prod-reader"
db_writer_instance_class       = "db.serverless"
db_serverless_min_capacity     = 0.5
db_serverless_max_capacity     = 8

# ---------- proxy_config (mirrors helm gateway.config.proxy_config) ----------
proxy_config = {
  model_list = [
    {
      model_name = "gpt-5.5"
      litellm_params = {
        model   = "openai/gpt-5.5"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
    {
      model_name = "gpt-5.4"
      litellm_params = {
        model   = "openai/gpt-5.4"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
    {
      model_name = "gpt-5.4-mini"
      litellm_params = {
        model   = "openai/gpt-5.4-mini"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
    {
      model_name = "gpt-5.3-codex"
      litellm_params = {
        model   = "openai/gpt-5.3-codex"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
    {
      model_name = "gpt-5.2"
      litellm_params = {
        model   = "openai/gpt-5.2"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
    {
      model_name = "smart-router"
      litellm_params = {
        model = "auto_router/complexity_router"
        complexity_router_config = {
          tiers = {
            SIMPLE    = "gpt-5.4-mini"
            MEDIUM    = "bedrock-anthropic-sonnet-5"
            COMPLEX   = "gpt-5.5"
            REASONING = "bedrock-anthropic-opus-4.8"
          }
        }
        complexity_router_default_model = "gpt-5.4-mini"
      }
    },
    {
      model_name = "smart-router-technical"
      litellm_params = {
        model = "auto_router/complexity_router"
        complexity_router_config = {
          tiers = {
            SIMPLE    = "gpt-5.4-mini"
            MEDIUM    = "bedrock-anthropic-sonnet-5"
            COMPLEX   = "gpt-5.5"
            REASONING = "bedrock-anthropic-opus-4.8"
          }
        }
        complexity_router_default_model = "gpt-5.4-mini"
      }
    },
    {
      model_name = "smart-router-rfp"
      litellm_params = {
        model = "auto_router/complexity_router"
        complexity_router_config = {
          tiers = {
            SIMPLE    = "gpt-5.4-mini"
            MEDIUM    = "bedrock-anthropic-sonnet-5"
            COMPLEX   = "bedrock-anthropic-opus-4.8"
            REASONING = "bedrock-anthropic-opus-4.8"
          }
          dimension_weights = {
            tokenCount         = 0.16
            codePresence       = 0.10
            reasoningMarkers   = 0.24
            technicalTerms     = 0.32
            simpleIndicators   = 0.10
            multiStepPatterns  = 0.05
            questionComplexity = 0.03
          }
          token_thresholds = {
            simple  = 20
            complex = 220
          }
          technical_keywords = [
            "proposal",
            "rfp",
            "requirements",
            "scope",
            "deliverables",
            "milestones",
            "timeline",
            "procurement",
            "commercial",
            "pricing",
            "compliance",
            "security",
            "governance",
            "architecture",
            "implementation",
            "sla"
          ]
          reasoning_keywords = [
            "analyze",
            "evaluate",
            "compare",
            "tradeoff",
            "recommend",
            "justify",
            "redraft",
            "rewrite",
            "improve",
            "structure",
            "step by step",
            "think through"
          ]
          simple_keywords = [
            "summarize",
            "rewrite briefly",
            "short email",
            "brief",
            "quick",
            "hello",
            "thanks"
          ]
        }
        complexity_router_default_model = "gpt-5.4-mini"
      }
    },
    {
      model_name = "codex-auto-review"
      litellm_params = {
        model   = "openai/gpt-5-mini"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    },
  ]
  general_settings = {
    master_key                        = "os.environ/LITELLM_MASTER_KEY"
    database_url                      = "os.environ/DATABASE_URL"
    enforce_email_prefix_on_key_alias = true
    # key_management_system             = "aws_secret_manager"
    # key_management_settings = {
    #   hosted_keys = [
    #     "MICROSOFT_ENTRA_CLIENT_ID",
    #     "MICROSOFT_ENTRA_CLIENT_SECRET",
    #     "MICROSOFT_ENTRA_TENANT"
    #   ]
    #   primary_secret_name = "data-reply/litellm/microsoft/entra"
    # }
    # auto_redirect_ui_login_to_sso = true

    alerting                    = ["email", "slack_budget_alerts", "slack"]
    alert_types                 = ["budget_alerts", "spend_reports"]
    alerting_threshold          = 300
    cancel_on_disconnect        = true
    enable_pre_call_checks      = true
    disable_spend_logs          = false
    disable_spend_updates       = false
    store_prompts_in_spend_logs = false

    alerting_args = {
      daily_report_frequency       = 43200 # 12 hours in seconds
      report_check_interval        = 3600  # 1 hour in seconds
      budget_alert_ttl             = 86400 # 24 hours in seconds
      outage_alert_ttl             = 60    # 1 minute in seconds
      region_outage_alert_ttl      = 60    # 1 minute in seconds
      minor_outage_alert_threshold = 5
      major_outage_alert_threshold = 10
      max_outage_alert_list_size   = 1000
      log_to_console               = false
    }
  },
  litellm_settings = {
    callbacks = ["smtp_email"]
    # Should solve https://github.com/BerriAI/litellm/issues/14194
    modify_params                      = true
    route_all_chat_openai_to_responses = true # Recommended
    mcp_semantic_tool_filter = {
      enabled              = true
      embedding_model      = "text-embedding-3-small"
      top_k                = 5
      similarity_threshold = 0.3
    }
    redact_messages_in_exceptions = true
    ui_theme_config = {
      logo_url    = "https://www.reply.com/favicon.ico"
      favicon_url = "https://www.reply.com/favicon.ico"
    }
  },
  # mcp_servers = {
  #   data_reply_sharepoint_server = {
  #     url           = ""
  #     transport     = "http"
  #     auth_type     = "oauth2"
  #     client_id     = "os.environ/SHAREPOINT_OAUTH_CREDENTIALS_CLIENT_ID"
  #     client_secret = "os.environ/SHAREPOINT_OAUTH_CREDENTIALS_CLIENT_SECRET"
  #   }
  # },
}

bedrock_models = [
  {
    model_name = "bedrock-zai-glm-4-7-flash"
    model      = "bedrock/zai.glm-4.7-flash"
  },
  {
    model_name = "bedrock-anthropic-haiku-4.5"
    model      = "bedrock/eu.anthropic.claude-haiku-4-5-20251001-v1:0"
    model_id   = "arn:aws:bedrock:eu-central-1:751812493785:inference-profile/eu.anthropic.claude-haiku-4-5-20251001-v1:0"
  },
  {
    model_name = "bedrock-anthropic-sonnet-5"
    model      = "bedrock/eu.anthropic.claude-sonnet-5"
  },
  {
    model_name = "bedrock-anthropic-opus-4.8"
    model      = "bedrock/eu.anthropic.claude-opus-4-8"
  }
]

# ---------- Extra env / secrets ----------
gateway_extra_env = {}

backend_extra_env = {
  SMTP_HOST         = "email-smtp.eu-central-1.amazonaws.com"
  SMTP_TLS          = "True"
  SMTP_PORT         = "587"
  SMTP_SENDER_EMAIL = "data.awsacccounts.management@reply.de"
  PROXY_BASE_URL    = "https://litellm.datareply.de"
  STORE_MODEL_IN_DB = true
  DISABLE_ADMIN_UI  = false
  # MICROSOFT_CLIENT_ID     = "os.environ/MICROSOFT_ENTRA_CLIENT_ID"
  # MICROSOFT_CLIENT_SECRET = "os.environ/MICROSOFT_ENTRA_CLIENT_SECRET"
  # MICROSOFT_TENANT        = "os.environ/MICROSOFT_ENTRA_TENANT"
}

backend_extra_secrets = {
  SMTP_USERNAME = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/smtp-username-GKDe9A"
  SMTP_PASSWORD = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/smtp-password-AonszW"
}

gateway_extra_secrets = {
  SLACK_WEBHOOK_URL = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/slack/webhook-reports-vXNOwY"
  OPENAI_API_KEY    = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/openai-api-key-nNpCF1"
}

