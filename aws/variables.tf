variable "name" {
  type        = string
  nullable    = false
  description = "The name for a stand. It will be used to name resources along with the environment."
}

variable "environment" {
  type        = string
  nullable    = false
  description = "The environment of a stand. It will be used to name resources along with the name."
}

variable "vpc_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of VPC to place resources. If it is not specified, the name along with the environment will be used."
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/17"
  validation {
    condition     = length(regexall("[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,3}", var.cidr)) > 0
    error_message = "The cidr value must be a valid IP network."
  }
  nullable    = false
  description = "The CIDR for the VPC."
}

variable "vpc_create" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if new VPC should be created."
}

variable "vpc_id" {
  type        = string
  default     = null
  nullable    = true
  description = "The ID of VPC to place resources. If it is not specified, the VPC for Datagrok will be created."
}

variable "vpc_single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks. We DO NOT recommend it for production usage."
  type        = bool
  default     = false
  nullable    = false
}

variable "vpc_subnets_count" {
  description = "The count of subnets to create; one subnet per availability zone in the region. If there are fewer availability zones than the subnets count, the availability zones count will take precedence. We recommend a minimum of 3 for production usage."
  type        = number
  default     = 3
  validation {
    condition     = var.vpc_subnets_count > 2
    error_message = "Minimum count of 2 subnets are allowed."
  }
  nullable = false
}

variable "public_subnet_ids" {
  type    = list(string)
  default = []
  validation {
    condition     = length(var.public_subnet_ids) >= 2 || length(var.public_subnet_ids) >= 0
    error_message = "The subnet_ids value must be a list with valid Subnet ids, starting with \"subnet-\"."
  }
  nullable    = true
  description = "The IDs of public subnets to place resources. Required if 'vpc_id' is specified."
}

variable "private_subnet_ids" {
  type    = list(string)
  default = []
  validation {
    condition     = length(var.private_subnet_ids) >= 2 || length(var.private_subnet_ids) >= 0
    error_message = "The subnet_ids value must be a list with valid Subnet ids, starting with \"subnet-\"."
  }
  nullable    = true
  description = "The IDs of private subnets to place resources. Required if 'vpc_id' is specified."
}
variable "flow_log_log_format" {
  type        = string
  default     = null
  nullable    = true
  description = "Flow logs format."
}

variable "flow_log_cloudwatch_log_group_name_prefix" {
  type        = string
  default     = "/aws/vpc-flow-log/"
  nullable    = true
  description = "Flow logs CloudWatch Log Group name prefix."
}

variable "enable_flow_logs" {
  type        = bool
  default     = true
  nullable    = false
  description = "Enable Flow logs for the VPC?"
}

variable "kms_key" {
  type        = string
  default     = null
  nullable    = true
  description = "The ID of custom KMS Key to encrypt resources."
}

variable "custom_kms_key" {
  type        = bool
  default     = false
  nullable    = false
  description = "Specifies whether a custom KMS key should be used to encrypt instead of the default. We recommend to set it to true for production stand."
}

variable "ecs_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of ECS cluster for Datagrok. If it is not specified, the name along with the environment will be used."
}

variable "lb_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of Datagrok load balancer. If it is not specified, the name along with the environment will be used."
}

variable "lb_access_cidr_blocks" {
  type        = string
  default     = "0.0.0.0/0"
  nullable    = false
  description = "The CIDR to from which the access Datagrok load balancer is allowed."
}

variable "egress_rules" {
  description = "List of egress rules to create by name"
  type        = list(any)
  default = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

variable "kms_owners" {
  description = "ARNs of who will be able to do all key operations/"
  type        = list(string)
  default     = null
  nullable    = true
}

variable "kms_admins" {
  description = "https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators"
  type        = list(string)
  default     = null
  nullable    = true
}

variable "kms_users" {
  description = "https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users"
  type        = list(string)
  default     = null
  nullable    = true
}

variable "ecs_launch_type" {
  type    = string
  default = "FARGATE"
  validation {
    condition     = var.ecs_launch_type == "FARGATE" || var.ecs_launch_type == "EC2"
    error_message = "The ecs_capacity_provider should either 'FARGATE' or 'EC2'"
  }
  nullable    = false
  description = "Launch type for datagrok containers. FARGATE and EC2 are available options. We recommend FARGATE for production stand."
}

variable "docker_hub_credentials" {
  type = object({
    create_secret = bool
    password      = optional(string)
    user          = optional(string)
    secret_arn    = optional(string)
  })
  default  = null
  nullable = true
  validation {
    condition     = try((var.docker_hub_credentials.create_secret && var.docker_hub_credentials.password != null && var.docker_hub_credentials.user != null) || (!var.docker_hub_credentials.create_secret && var.docker_hub_credentials.secret_arn != null), var.docker_hub_credentials == null)
    error_message = "The Docker Hub credentials should be specified. Either user-password pair or AWS Secret ARN."
  }
  description = "Docker Hub credentials to download images.\n`create_secret` - Specifies if new secret with Docker Hub credentials will be created.\n`user` - Docker Hub User to access Docker Hub and download datagrok images. Can be ommited if `secret_arn` is specified\n`password` - Docker Hub Token to access Docker Hub and download datagrok images. Can be ommited if `secret_arn` is specified\n`secret_arn` - The ARN of AWS Secret which contains Docker Hub Token to access Docker Hub and download datagrok images. If not specified the secret will be created using `user` and `password` variables\nEither user(`user`) - password(`password`) pair or AWS Secret ARN (`secret_arn`) should be specified."
}

variable "ecr_enabled" {
  type        = bool
  default     = false
  nullable    = false
  description = "Specifies whether terraform copy images to ECR and use it instead of `docker_<service>_image`"
}

variable "ecr_image_scan_on_push" {
  type        = bool
  default     = true
  nullable    = false
  description = "Indicates whether images are scanned after being pushed to the repository (true) or not scanned (false)."
}

variable "ecr_principal_restrict_access" {
  type        = bool
  default     = false
  nullable    = false
  description = "Specifies whether ECR restrictive policy is enabled. We recommend to set it to true for production stand."
}

variable "ecr_policy_principal" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "List of principal ARNs which will have access to ECR. By default it is limited to the caller ARN."
}

variable "tags" {
  type        = map(string)
  default     = {}
  nullable    = false
  description = "Key-value map of resource tags."
}

variable "domain_name" {
  type        = string
  default     = ""
  nullable    = true
  description = "This is the name of domain for datagrok endpoint. It is used for the external hosted zone in Route53 and to create ACM certificates."
}

variable "route53_enabled" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if the Route53 is used for DNS."
}

variable "create_route53_external_zone" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if the Route53 external hosted zone for the domain should be created. If not specified some other DNS service should be used instead of Route53 or existing Route53 zone."
}

variable "create_route53_internal_zone" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if the Route53 internal hosted zone for the domain should be created. If if is set to false route53_internal_zone is required"
}

variable "route53_record_name" {
  type        = string
  default     = null
  nullable    = true
  description = "This is the name of record in Route53 for Datagrok. If if is not set the name along with environment will be used."
}

variable "route53_internal_zone" {
  type        = string
  default     = null
  nullable    = true
  description = "Route53 internal hosted zone ID. If it is not set create_route53_internal_zone is required to be true"
}

variable "service_discovery_namespace" {
  type = object({
    create = bool
    id     = optional(string)
  })
  default = {
    create = true
  }
  nullable = false
  validation {
    condition     = (var.service_discovery_namespace.id != null && !var.service_discovery_namespace.create) || (var.service_discovery_namespace.id == null && var.service_discovery_namespace.create)
    error_message = "Either id or create should be specified."
  }
  description = "Service discovery namespace for FARGATE tasks. Set 'create' to 'true' to create new one. Or set 'create' to 'false' and 'id' to AWS Service Discovery Namespace ID to use the existing one."
}

variable "acm_cert_create" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if the ACM certificate should be created."
}

variable "acm_cert_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "ACM certificate ARN for Datagrok endpoint. If it is not set it will be created"
}

variable "subject_alternative_names" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "List for alternative names for ACM certificate"
}

variable "ec2_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of Datagrok EC2 instance. If it is not specified, the name along with the environment will be used."
}

variable "ami_id" {
  type        = string
  default     = null
  nullable    = true
  description = "The AMI ID for Datagrok EC2 instance. If it is not specified, the basic AWS ECS optimized AMI will be used."
}

variable "instance_type" {
  type        = string
  default     = "c5.xlarge"
  nullable    = false
  description = "EC2 instance type. The default value is the minimum recommended type."
}

variable "root_volume_throughput" {
  type        = number
  default     = null
  nullable    = true
  description = "EC2 root volume throughput."
}

variable "termination_protection" {
  type        = bool
  default     = true
  nullable    = false
  description = "Termination protection for the resources created by module."
}

variable "public_key" {
  type        = string
  default     = null
  nullable    = true
  description = "SSH Public Key to create keypair in AWS and access EC2 instance. If not set key_pair_name is required."
}

variable "key_pair_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Existing SSH Key Pair name for access to EC2 instance. If not set public_key is required."
}

variable "cloudwatch_log_group_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of Datagrok CloudWatch Log Group. If it is not specified, the name along with the environment will be used."
}

variable "cloudwatch_log_group_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "The ARM of existing CloudWatch Log Group to use with Datagrok."
}

variable "docker_grok_compute_image" {
  type        = string
  default     = "docker.io/datagrok/grok_compute"
  nullable    = false
  description = "Grok Compute Docker Image registry location. By default the official image from Docker Hub will be used."
}

variable "docker_grok_compute_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker registry for Grok Compute Docker Image"
}

variable "docker_jupyter_image" {
  type        = string
  default     = "docker.io/datagrok/jupyter"
  nullable    = false
  description = "Jupyter Docker Image registry location. By default the official image from Docker Hub will be used."
}

variable "docker_jupyter_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker registry for Jupyter Docker Image"
}

variable "docker_h2o_image" {
  type        = string
  default     = "docker.io/datagrok/h2o"
  nullable    = false
  description = "H2O Docker Image registry location. By default the official image from Docker Hub will be used."
}

variable "docker_h2o_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker registry for H2O Docker Image"
}

variable "create_cloudwatch_log_group" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies if the CloudWatch Log Group should be created. If it is set to false cloudwatch_log_group_arn is required."
}

variable "ecs_cluster_insights" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether Monitoring Insights for ECS cluster are enabled. We recommend to set it to true for production stand."
}

variable "ec2_detailed_monitoring_enabled" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether Monitoring Insights for EC2 instance are enabled. We recommend to set it to true for production stand."
}

variable "monitoring" {
  type = object({
    alarms_enabled        = bool
    create_sns_topic      = bool
    sns_topic_arn         = optional(string)
    sns_topic_name        = optional(string)
    email_alerts          = optional(bool, true)
    email_recipients      = optional(list(string), [])
    email_alerts_datagrok = bool
    slack_alerts          = optional(bool, false)
    slack_emoji           = optional(string)
    slack_webhook_url     = optional(string)
    slack_channel         = optional(string)
    slack_username        = optional(string)
  })
  default = {
    alarms_enabled        = true
    create_sns_topic      = true
    email_alerts          = true
    email_alerts_datagrok = true
    slack_alerts          = false
  }
  nullable    = false
  description = "Monitoring object.\n`alarms_enabled` - Specifies whether CloudWatch Alarms are enabled. We recommend to set it to true for production stand.\n`create_sns_topic` - Specifies whether Datagrok SNS topic should be created. If it is set to false, `sns_topic_arn` is required.\n`sns_topic_name` - The name of Datagrok SNS topic. If it is not specified, the name along with the environment will be used.\n`sns_topic_arn` - An ARN of the custom SNS topic for CloudWatch alarms.\n`email_alerts` - Specifies whether CloudWatch Alarms are forwarded to Email. We recommend to set it to true for production stand.\n`email_recipients` - List of email addresses to receive CloudWatch Alarms.\n`email_alerts_datagrok` - Specifies whether CloudWatch Alarms are forwarded to Datagrok Email. We recommend to set it to true for production stand.\n`slack_alerts` - Specifies whether CloudWatch Alarms are forwarded to Slack. We recommend to set it to true for production stand.\n`slack_emoji` - A custom emoji that will appear on Slack messages from CloudWatch alarms.\n`slack_webhook_url` - The URL of Slack webhook for CloudWatch alarm notifications.\n`slack_channel` - The name of the channel in Slack for notifications from CloudWatch alarms.\n`slack_username` - The username that will appear on Slack messages from CloudWatch alarms."
}

variable "enable_route53_logging" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether Logging requests using server access logging for Datagrok Route53 zone are enabled. We recommend to set it to true for production stand."
}

variable "grok_compute_container_memory_reservation" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The soft limit (in MiB) of memory to reserve for the Grok Compute container."
}

variable "grok_compute_container_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The number of cpu units the Amazon ECS container agent reserves for the Grok Compute container."
}

variable "grok_compute_memory" {
  type        = number
  default     = 2048
  nullable    = false
  description = "Amount (in MiB) of memory used by the Grok Compute FARGATE task. The hard limit of memory (in MiB) to present to the task."
}

variable "grok_compute_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "Number of cpu units used by the Grok Compute FARGATE task. The hard limit of CPU units to present for the task."
}

variable "jupyter_container_memory_reservation" {
  type        = number
  default     = 2048
  nullable    = false
  description = "The soft limit (in MiB) of memory to reserve for the Jupyter container."
}

variable "jupyter_container_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The number of cpu units the Amazon ECS container agent reserves for the Jupyter container."
}

variable "jupyter_memory" {
  type        = number
  default     = 3072
  nullable    = false
  description = "Amount (in MiB) of memory used by the Jupyter FARGATE task. The hard limit of memory (in MiB) to present to the task."
}

variable "jupyter_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "Number of cpu units used by the Jupyter FARGATE task. The hard limit of CPU units to present for the task."
}

variable "h2o_container_memory_reservation" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The soft limit (in MiB) of memory to reserve for the H2O container."
}

variable "h2o_container_cpu" {
  type        = number
  default     = 512
  nullable    = false
  description = "The number of cpu units the Amazon ECS container agent reserves for the H2O container."
}

variable "h2o_memory" {
  type        = number
  default     = 2048
  nullable    = false
  description = "Amount (in MiB) of memory used by the H2O FARGATE task. The hard limit of memory (in MiB) to present to the task."
}

variable "h2o_cpu" {
  type        = number
  default     = 512
  nullable    = false
  description = "Number of cpu units used by the H2O FARGATE task. The hard limit of CPU units to present for the task."
}

variable "bucket_logging" {
  type = object({
    log_bucket        = optional(string)
    create_log_bucket = bool
    enabled           = bool
  })
  default = {
    enabled           = true
    create_log_bucket = true
  }
  nullable = false
  validation {
    condition     = !var.bucket_logging.enabled || (var.bucket_logging.enabled && ((var.bucket_logging.log_bucket != null && !var.bucket_logging.create_log_bucket) || (var.bucket_logging.log_bucket == null && var.bucket_logging.create_log_bucket)))
    error_message = "Either create_log_bucket or AWS Log Bucket ID should be specified."
  }
  description = "Bucket Logging object.\n `enabled` - Specifies whether Logging requests using server access logging for Datagrok S3 bucket are enabled. We recommend to set it to true for production stand.\n`create_log_bucket` - Specifies whether the S3 log bucket will be created.\n`log_bucket` - The name of S3 logging bucket. If it is not specified, the S3 log bucket for Datagrok S3 bucket will be created."
}
