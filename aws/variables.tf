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

variable "vpc_id" {
  type        = string
  default     = null
  nullable    = true
  description = "The ID of VPC to place resources. If it is not specified, the VPC for Datagrok will be created."
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

variable "enable_bucket_logging" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether Logging requests using server access logging for Datagrok S3 bucket are enabled. We recommend to set it to true for production stand."
}


variable "log_bucket" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of S3 logging bucket. If it is not specified, the S3 log bucket for Datagrok S3 bucket will be created."
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

variable "docker_hub_password" {
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
  description = "Docker Hub Token to access Docker Hub and download datagrok images. Can be ommited if docker_hub_secret_arn is specified"
}

variable "docker_hub_user" {
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
  description = "Docker Hub User to access Docker Hub and download datagrok images. Can be ommited if docker_hub_secret_arn is specified"
}

variable "docker_hub_secret_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "The ARN of AWS Secret which contains Docker Hub Token to access Docker Hub and download datagrok images. If not specified the secret will be created using docker_hub_password variable"
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
  description = "This is the name of domain for datagrok endpoint. It is used for the external hosted zone in Route53. and to create ACM certificates."
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
  type        = string
  default     = null
  nullable    = true
  description = "Service discovery namespace ID for FARGATE tasks. If it is not set it will be created"
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

variable "docker_grok_compute_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker Hub for datagrok/grok_compute image"
}

variable "docker_jkg_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker Hub for datagrok/jupyter_kernel_gateway image"
}

variable "docker_jn_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker Hub for datagrok/jupyter_notebook image"
}

variable "docker_h2o_tag" {
  type        = string
  default     = "latest"
  nullable    = false
  description = "Tag from Docker Hub for datagrok/h2o image"
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

variable "monitoring_sns_topic_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "An ARN of the custom SNS topic for CloudWatch alarms."
}

variable "monitoring_email_recipients" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "List of email addresses to receive CloudWatch Alarms."
}

variable "monitoring_email_alerts_datagrok" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether CloudWatch Alarms are forwarded to Datagrok Email. We recommend to set it to true for production stand."
}

variable "monitoring_slack_emoji" {
  type        = string
  default     = null
  nullable    = true
  description = "A custom emoji that will appear on Slack messages from CloudWatch alarms."
}

variable "monitoring_email_alerts" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether CloudWatch Alarms are forwarded to Email. We recommend to set it to true for production stand."
}

variable "monitoring_slack_webhook_url" {
  type        = string
  default     = null
  nullable    = true
  description = "The URL of Slack webhook for CloudWatch alarm notifications."
}

variable "monitoring_slack_channel" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of the channel in Slack for notifications from CloudWatch alarms."
}

variable "monitoring_slack_username" {
  type        = string
  default     = null
  nullable    = true
  description = "The username that will appear on Slack messages from CloudWatch alarms."
}

variable "monitoring_alarms" {
  type        = bool
  default     = true
  nullable    = false
  description = "Specifies whether CloudWatch Alarms are enabled. We recommend to set it to true for production stand."
}

variable "monitoring_slack_alerts" {
  type        = bool
  default     = false
  nullable    = false
  description = "Specifies whether CloudWatch Alarms are forwarded to Slack. We recommend to set it to true for production stand."
}

variable "sns_topic_name" {
  type        = string
  default     = null
  nullable    = true
  description = "The name of Datagrok SNS topic. If it is not specified, the name along with the environment will be used."
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

variable "jkg_container_memory_reservation" {
  type        = number
  default     = 2048
  nullable    = false
  description = "The soft limit (in MiB) of memory to reserve for the Jupyter Kernel Gateway container."
}

variable "jkg_container_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The number of cpu units the Amazon ECS container agent reserves for the Jupyter Kernel Gateway container."
}

variable "jkg_memory" {
  type        = number
  default     = 3072
  nullable    = false
  description = "Amount (in MiB) of memory used by the Jupyter Kernel Gateway FARGATE task. The hard limit of memory (in MiB) to present to the task."
}

variable "jkg_cpu" {
  type        = number
  default     = 1024
  nullable    = false
  description = "Number of cpu units used by the Jupyter Kernel Gateway FARGATE task. The hard limit of CPU units to present for the task."
}

variable "jn_container_memory_reservation" {
  type        = number
  default     = 1024
  nullable    = false
  description = "The soft limit (in MiB) of memory to reserve for the Jupyter Notebook container."
}

variable "jn_container_cpu" {
  type        = number
  default     = 512
  nullable    = false
  description = "The number of cpu units the Amazon ECS container agent reserves for the Jupyter Notebook container."
}

variable "jn_memory" {
  type        = number
  default     = 2048
  nullable    = false
  description = "Amount (in MiB) of memory used by the Jupyter Notebook FARGATE task. The hard limit of memory (in MiB) to present to the task."
}

variable "jn_cpu" {
  type        = number
  default     = 512
  nullable    = false
  description = "Number of cpu units used by the Jupyter Notebook FARGATE task. The hard limit of CPU units to present for the task."
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
