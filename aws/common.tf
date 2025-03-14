locals {
  tags = merge(var.tags, {
    Service     = "Datagrok"
    FullName    = "${var.name}-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  })
  full_name      = "${var.name}-${var.environment}"
  vpc_name       = coalesce(var.vpc_name, "${var.name}-${var.environment}")
  ecs_name       = coalesce(var.ecs_name, "${var.name}-${var.environment}")
  lb_name        = coalesce(var.lb_name, "${var.name}-${var.environment}")
  rabbitmq_name   = coalesce(var.rabbitmq_name, "${var.name}-${var.environment}")
  ec2_name       = coalesce(var.ec2_name, "${var.name}-${var.environment}")
  sns_topic_name = coalesce(var.monitoring.sns_topic_name, "${var.name}-${var.environment}")
  r53_record     = var.route53_enabled ? try("${var.route53_record_name}.${var.domain_name}", "${var.name}-${var.environment}.${var.domain_name}") : ""
  create_kms     = var.custom_kms_key && !try(length(var.kms_key) > 0, false)

  images = {
    jupyter_kernel_gateway = {
      image = var.docker_jkg_image
      tag   = var.docker_jkg_tag == "latest" ? "${var.docker_jkg_tag}-${formatdate("YYYYMMDDhhmmss", timestamp())}" : var.docker_jkg_tag
    },
    "ecs-searchdomain-sidecar-${var.name}-${var.environment}" = {
      image = "docker/ecs-searchdomain-sidecar"
      tag   = "1.0"
    }
  }

  targets = {
  }
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
