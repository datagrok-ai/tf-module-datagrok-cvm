locals {
  tags = merge(var.tags, {
    Service     = "Datagrok"
    FullName    = "${var.name}-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  })
  full_name      = "${var.name}-${var.environment}"
  vpc_name       = try(length(var.vpc_name) > 0, false) ? var.vpc_name : "${var.name}-${var.environment}"
  ecs_name       = try(length(var.ecs_name) > 0, false) ? var.ecs_name : "${var.name}-${var.environment}"
  lb_name        = try(length(var.lb_name) > 0, false) ? var.lb_name : "${var.name}-${var.environment}"
  ec2_name       = try(length(var.ec2_name) > 0, false) ? var.ec2_name : "${var.name}-${var.environment}"
  sns_topic_name = try(length(var.sns_topic_name) > 0, false) ? var.sns_topic_name : "${var.name}-${var.environment}"
  r53_record     = var.route53_enabled ? try(length(var.route53_record_name) > 0, false) ? "${var.route53_record_name}.${var.domain_name}" : "${var.name}-${var.environment}.${var.domain_name}" : ""
  create_kms     = var.custom_kms_key && !try(length(var.kms_key) > 0, false)

  log_bucket = var.bucket_logging.enabled && var.bucket_logging.log_bucket != null ? var.bucket_logging.log_bucket : module.log_bucket.s3_bucket_id

  targets = [
    {
      name             = "gc"
      backend_protocol = "HTTP"
      backend_port     = 5005
      target_type      = aws_ecs_task_definition.grok_compute.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/grok_compute/info"
        matcher             = "200"
      }
    },
    {
      name             = "jkg"
      backend_protocol = "HTTP"
      backend_port     = 8888
      target_type      = aws_ecs_task_definition.jkg.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/jupyter/api/swagger.yaml"
        matcher             = "200"
      }
    },
    {
      name             = "jkgH"
      backend_protocol = "HTTP"
      backend_port     = 5005
      target_type      = aws_ecs_task_definition.jkg.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/jupyter/helper/info"
        matcher             = "200"
      }
    },
    {
      name             = "jn"
      backend_protocol = "HTTP"
      backend_port     = 8889
      target_type      = aws_ecs_task_definition.jn.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/notebook/api"
        matcher             = "200"
      }
    },
    {
      name             = "jnH"
      backend_protocol = "HTTP"
      backend_port     = 5005
      target_type      = aws_ecs_task_definition.jn.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/notebook/helper/info"
        matcher             = "200"
      }
    },
    {
      name             = "h2oH"
      backend_protocol = "HTTP"
      backend_port     = 5005
      target_type      = aws_ecs_task_definition.h2o.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/helper/info"
        matcher             = "200"
      }
    },
    {
      name             = "h2o"
      backend_protocol = "HTTP"
      backend_port     = 54321
      target_type      = aws_ecs_task_definition.h2o.network_mode == "awsvpc" ? "ip" : "instance"
      health_check = {
        enabled             = true
        interval            = 60
        unhealthy_threshold = 5
        path                = "/3/About"
        matcher             = "200"
      }
    }
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
module "kms" {
  count   = local.create_kms ? 1 : 0
  source  = "registry.terraform.io/terraform-aws-modules/kms/aws"
  version = "~> 1.1.0"

  aliases                 = [local.full_name]
  description             = "Datagrok KMS for ${local.full_name}"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  is_enabled              = true
  create_external         = false
  multi_region            = false

  # Policy
  enable_default_policy = true
  key_owners = try(length(var.kms_owners) > 0, false) ? var.kms_owners : [
    data.aws_caller_identity.current.arn
  ]
  key_administrators = try(length(var.kms_admins) > 0, false) ? var.kms_admins : [
    data.aws_caller_identity.current.arn
  ]
  key_users = try(length(var.kms_users) > 0, false) ? var.kms_users : [data.aws_caller_identity.current.arn]
  #  key_service_users     = [
  #    aws_iam_role.task.arn,
  #    aws_iam_role.exec.arn,
  #    aws_iam_role.datagrok_service.arn,
  #    aws_iam_instance_profile.datagrok_profile[0].arn
  #  ]

  tags = local.tags
}
