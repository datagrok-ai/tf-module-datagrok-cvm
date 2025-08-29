resource "random_string" "lb_id" {
  for_each = local.targets
  length   = 2
  special  = false
  keepers = {
    target_type = each.value["target_type"]

  }
}

data "aws_route53_zone" "external" {
  count        = !var.create_route53_external_zone && var.route53_enabled ? 1 : 0
  name         = var.domain_name
  private_zone = false
}
resource "aws_route53_zone" "external" {
  count = var.create_route53_external_zone && var.route53_enabled ? 1 : 0
  name  = var.domain_name
  tags  = local.tags
}

provider "aws" {
  alias  = "datagrok-cloudwatch-r53-external"
  region = "us-east-1"
}

resource "aws_cloudwatch_log_group" "external" {
  provider          = aws.datagrok-cloudwatch-r53-external
  count             = var.route53_enabled && var.enable_route53_logging && var.create_route53_external_zone ? 1 : 0
  name              = "/aws/route53/${aws_route53_zone.external[0].name}"
  retention_in_days = 7
  #checkov:skip=CKV_AWS_158:The KMS key is configurable
  kms_key_id = var.custom_kms_key ? try(module.kms[0].key_arn, var.kms_key) : null
  tags       = local.tags
}

data "aws_iam_policy_document" "external" {
  count = var.route53_enabled && var.enable_route53_logging && var.create_route53_external_zone ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/route53/*"]
    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "external" {
  provider        = aws.datagrok-cloudwatch-r53-external
  count           = var.route53_enabled && var.enable_route53_logging && var.create_route53_external_zone ? 1 : 0
  policy_document = data.aws_iam_policy_document.external[0].json
  policy_name     = "${var.name}-${var.environment}-route53"
}

resource "aws_route53_query_log" "external" {
  count                    = var.route53_enabled && var.enable_route53_logging && var.create_route53_external_zone ? 1 : 0
  depends_on               = [aws_cloudwatch_log_resource_policy.external]
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.external[0].arn
  zone_id                  = aws_route53_zone.external[0].zone_id
}

resource "aws_route53_zone" "internal" {
  count = var.create_route53_internal_zone ? 1 : 0
  name  = "datagrok.${var.name}.${var.environment}.internal"
  tags  = local.tags
  vpc {
    vpc_id = try(module.vpc[0].vpc_id, var.vpc_id)
  }
}
