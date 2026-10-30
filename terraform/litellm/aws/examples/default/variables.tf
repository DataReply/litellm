# Curated surface for the one-command deploy path. The module (../../)
# exposes far more knobs (per-component CPU/memory, autoscaling, RDS/Redis
# sizing, …). To tune those, set them directly on the `module "litellm"`
# block in main.tf, or call the module from your own root config. Full
# per-variable docs live in ../../variables.tf — the module is the source
# of truth; descriptions here are intentionally terse.

variable "region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "tenant" {
  description = "Tenant slug — prefix for every resource (<tenant>-litellm-<env>)."
  type        = string
}

variable "env" {
  description = "Environment suffix (stage, prod, dev)."
  type        = string
}

variable "azs" {
  description = "Availability zones for the subnets the module creates. At least 2 (RDS + ALB). Unused when vpc_id is set."
  type        = list(string)
  default     = []
}

# Bring-your-own networking. Leave vpc_id empty to have the module create the
# VPC, subnets, NAT gateway, and route tables.
variable "vpc_id" {
  description = "Existing VPC to deploy into. Empty → module creates its own networking."
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Existing public subnets for the ALB (≥ 2 AZs). Required with vpc_id."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Existing private subnets for tasks, Aurora, and Redis. Required with vpc_id."
  type        = list(string)
  default     = []
}

variable "additional_task_security_group_ids" {
  description = "Extra security groups for the tasks, e.g. one an existing database already allows."
  type        = list(string)
  default     = []
}

# Bring-your-own data stores. create_* false with an empty URL runs without
# that component: no DB means no key management or spend tracking, no Redis
# means per-task rate limits instead of cluster-wide.
variable "create_database" {
  description = "Create the Aurora Postgres cluster. False → use database_url, or run DB-less."
  type        = bool
  default     = true
}

variable "database_url" {
  description = "Postgres connection string for an existing database. Read only when create_database = false."
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_redis" {
  description = "Create the ElastiCache Redis group. False → use redis_url, or run without Redis."
  type        = bool
  default     = true
}

variable "redis_url" {
  description = "Connection string for an existing Redis. Read only when create_redis = false."
  type        = string
  default     = ""
  sensitive   = true
}

# Sensitive — prefer TF_VAR_litellm_master_key / TF_VAR_litellm_license /
# TF_VAR_ui_password so values stay out of any committed tfvars file.
variable "litellm_master_key" {
  description = "Pre-existing LITELLM_MASTER_KEY (sk-…). Empty → auto-generated."
  type        = string
  default     = ""
  sensitive   = true
}

variable "litellm_license" {
  description = "LiteLLM enterprise license. Empty → OSS-only."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ui_password" {
  description = "UI admin password. Empty → falls back to LITELLM_MASTER_KEY."
  type        = string
  default     = ""
  sensitive   = true
}

# TLS — provide an ACM cert for production, or opt into HTTP-only for dev.
variable "acm_certificate_domain_name" {
  description = "ACM cert domain name for the ALB HTTPS listener. Empty → no TLS."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the TLS hostname. Empty → manage DNS elsewhere."
  type        = string
  default     = ""
}

variable "allow_plaintext_alb" {
  description = "Opt into HTTP-only ALB (trial/dev only)."
  type        = bool
  default     = false
}

variable "s3_force_destroy" {
  description = "Allow destroy of a non-empty S3 bucket (ephemeral/CI only)."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the Aurora final snapshot on destroy (ephemeral/CI only)."
  type        = bool
  default     = false
}

variable "db_enable_reader" {
  description = "Create a reader instance alongside the primary instance."
  type        = bool
  default     = true
}

variable "db_primary_instance_identifier" {
  description = "DB instance identifier for the primary instance. Leave unset to use the module default."
  type        = string
  default     = null
}

variable "db_reader_instance_identifier" {
  description = "DB instance identifier for the reader instance. Leave unset to use the module default."
  type        = string
  default     = null
}

variable "db_writer_instance_class" {
  description = "Aurora instance class for the primary instance. Leave unset to use the module default."
  type        = string
  default     = null
}

variable "db_reader_instance_class" {
  description = "Aurora instance class for the reader instance. Leave unset to use the module default."
  type        = string
  default     = null
}

variable "db_serverless_min_capacity" {
  description = "Aurora Serverless v2 minimum ACUs. Empty means leave unmanaged by this wrapper."
  type        = number
  default     = null
}

variable "db_serverless_max_capacity" {
  description = "Aurora Serverless v2 maximum ACUs. Empty means leave unmanaged by this wrapper."
  type        = number
  default     = null
}

variable "proxy_config" {
  description = "LiteLLM proxy config (contents of config.yaml). Empty → defaults."
  type        = any
  default     = {}
}

variable "bedrock_models" {
  description = "Bedrock deployments to expose through LiteLLM. Empty leaves Bedrock unmanaged."
  type = list(object({
    model_name = string
    model      = string
    model_id   = optional(string)
  }))
  default = []
}

variable "gateway_extra_env" {
  description = "Plain-text env vars layered onto the gateway."
  type        = map(string)
  default     = {}
}

variable "backend_extra_env" {
  description = "Plain-text env vars layered onto the backend."
  type        = map(string)
  default     = {}
}

variable "gateway_extra_secrets" {
  description = "Gateway env vars sourced from Secrets Manager (name → ARN)."
  type        = map(string)
  default     = {}
}

variable "backend_extra_secrets" {
  description = "Backend env vars sourced from Secrets Manager (name → ARN)."
  type        = map(string)
  default     = {}
}

variable "gateway_metrics_port" {
  description = "Port for the Prometheus metrics sidecar in the gateway task. Null keeps /metrics on the gateway port only."
  type        = number
  default     = null
}

variable "gateway_metrics_scrape_cidrs" {
  description = "CIDRs allowed to scrape gateway_metrics_port."
  type        = list(string)
  default     = []
}
