region = "eu-central-1"
azs    = ["eu-central-1a", "eu-central-1b"]

tenant = "data-reply"
env    = "dev"

ecr_force_delete = true

vpc_id   = ""
vpc_cidr = "10.41.0.0/16"

gateway_desired_count       = 1
backend_desired_count       = 1
ui_desired_count            = 1
gateway_autoscaling_enabled = false
backend_autoscaling_enabled = false
ui_autoscaling_enabled      = false

create_database            = true
db_enable_reader           = false
db_writer_instance_class   = "db.serverless"
db_serverless_min_capacity = 0.5
db_serverless_max_capacity = 2
db_engine_version          = "16.11"

db_randomize_final_snapshot_name = true

create_redis       = true
redis_num_replicas = 0

acm_certificate_domain_name = "litellm-dev.datareply.de"
route53_zone_id             = "Z0891217221E1PTCMOPWZ"

proxy_config = {
  model_list = [
    {
      model_name = "gpt-6-luna"
      litellm_params = {
        model   = "openai/gpt-6-luna"
        api_key = "os.environ/OPENAI_API_KEY"
      }
    }
  ]
  general_settings = {
    master_key                  = "os.environ/LITELLM_MASTER_KEY"
    database_url                = "os.environ/DATABASE_URL"
    store_prompts_in_spend_logs = false
  }
  litellm_settings = {
    route_all_chat_openai_to_responses = true
    redact_messages_in_exceptions      = true
    ui_theme_config = {
      logo_url    = "https://www.reply.com/favicon.ico"
      favicon_url = "https://www.reply.com/favicon.ico"
    }
  }
}

backend_extra_env = {
  PROXY_BASE_URL = "https://litellm-dev.datareply.de"
}

gateway_extra_secrets = {
  OPENAI_API_KEY = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/openai-api-key-nNpCF1"
}

/*backend_extra_secrets = {
  OPENAI_API_KEY = "arn:aws:secretsmanager:eu-central-1:751812493785:secret:data-reply/litellm/openai-api-key-nNpCF1"
}*/
