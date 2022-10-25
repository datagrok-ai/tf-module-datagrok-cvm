module "lb_ext_sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.12.0"

  name        = local.lb_name
  description = "${local.lb_name} Datagrok LB Security Group"
  vpc_id      = try(length(var.vpc_id) > 0, false) ? var.vpc_id : module.vpc[0].vpc_id

  egress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "Datagrok egress rules from LB to ECS"
      source_security_group_id = module.sg.security_group_id
    },
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Access to HTTP"
      cidr_blocks = var.lb_access_cidr_blocks
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Access to HTTPS"
      cidr_blocks = var.lb_access_cidr_blocks
    },
  ]
}
module "lb_int_sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.12.0"

  name        = "${local.lb_name}-int"
  description = "${local.lb_name}-int Datagrok LB Security Group"
  vpc_id      = try(length(var.vpc_id) > 0, false) ? var.vpc_id : module.vpc[0].vpc_id

  egress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 65535
      protocol                 = "tcp"
      description              = "Datagrok egress rules from LB to ECS"
      source_security_group_id = module.sg.security_group_id
    },
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Access to Datagrok Nginx"
      cidr_blocks = try(length(var.vpc_id) > 0, false) ? var.cidr : module.vpc[0].vpc_cidr_block
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Access to Datagrok Nginx"
      cidr_blocks = try(length(var.vpc_id) > 0, false) ? var.cidr : module.vpc[0].vpc_cidr_block
    },
  ]
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
module "acm" {
  source  = "registry.terraform.io/terraform-aws-modules/acm/aws"
  version = "~> 3.5.0"
  count   = try(length(var.acm_cert_arn) > 0, false) ? 0 : 1

  domain_name       = var.domain_name
  zone_id           = var.route53_enabled ? data.aws_route53_zone.external[0].zone_id : null
  validation_method = "DNS"

  subject_alternative_names = var.subject_alternative_names

  create_route53_records = var.route53_enabled
  validate_certificate   = true
  wait_for_validation    = true
  validation_record_fqdns = var.route53_enabled ? null : distinct(
    [
      for domain in concat(
        [
          var.domain_name
        ],
      var.subject_alternative_names) : "_f36e88adbd7b4c92a11a58ffc7f6808e.${replace(domain, "*.", "")}"
    ]
  )

  tags = local.tags
}
module "lb_ext" {
  source  = "registry.terraform.io/terraform-aws-modules/alb/aws"
  version = "~> 6.10.0"

  name                       = "${local.lb_name}-ext"
  load_balancer_type         = "application"
  vpc_id                     = try(length(var.vpc_id) > 0, false) ? var.vpc_id : module.vpc[0].vpc_id
  subnets                    = try(length(var.vpc_id) > 0, false) ? var.public_subnet_ids : module.vpc[0].public_subnets
  security_groups            = [module.lb_ext_sg.security_group_id]
  drop_invalid_header_fields = true

  access_logs = var.enable_bucket_logging ? {
    bucket  = try(length(var.log_bucket) > 0, false) ? var.log_bucket : module.log_bucket[0].s3_bucket_id
    prefix  = "lb"
    enabled = true
  } : { bucket = "", enabled = false }

  target_groups = [for target in local.targets : merge(target, { name = "${local.lb_name}-ext-${target["name"]}" })]

  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = try(length(var.acm_cert_arn) > 0, false) ? var.acm_cert_arn : module.acm[0].acm_certificate_arn
      action_type     = "fixed-response"
      fixed_response = {
        status_code  = 204
        message_body = "No content. Try other endpoints for the URL: /jupyter, /notebook, /grok_compute."
        content_type = "text/plain"
      }
    },
    {
      port               = 5005
      protocol           = "HTTPS"
      certificate_arn    = try(length(var.acm_cert_arn) > 0, false) ? var.acm_cert_arn : module.acm[0].acm_certificate_arn
      target_group_index = 5
    },
    {
      port               = 54321
      protocol           = "HTTPS"
      certificate_arn    = try(length(var.acm_cert_arn) > 0, false) ? var.acm_cert_arn : module.acm[0].acm_certificate_arn
      target_group_index = 6
    }
  ]

  http_tcp_listeners = [
    {
      action_type = "redirect"
      port        = 80
      protocol    = "HTTP"
      redirect = {
        port        = 443
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listener_rules = [
    {
      https_listener_index = 0
      priority             = 1
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [
        {
          path_patterns = ["/grok_compute/*"]
        }
      ]
    },
    {
      https_listener_index = 0
      priority             = 2
      actions = [
        {
          type               = "forward"
          target_group_index = 2
        }
      ]
      conditions = [
        {
          path_patterns = ["/jupyter/helper/*"]
        }
      ]
    },
    {
      https_listener_index = 0
      priority             = 3
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]
      conditions = [
        {
          path_patterns = ["/jupyter/*"]
        }
      ]
    },
    {
      https_listener_index = 0
      priority             = 4
      actions = [
        {
          type               = "forward"
          target_group_index = 4
        }
      ]
      conditions = [
        {
          path_patterns = ["/notebook/helper/*"]
        }
      ]
    },
    {
      https_listener_index = 0
      priority             = 5
      actions = [
        {
          type               = "forward"
          target_group_index = 3
        }
      ]
      conditions = [
        {
          path_patterns = ["/notebook/*"]
        }
      ]
    },
  ]

  tags = local.tags
}
module "lb_int" {
  source  = "registry.terraform.io/terraform-aws-modules/alb/aws"
  version = "~> 6.10.0"

  name                       = "${local.lb_name}-int"
  load_balancer_type         = "application"
  vpc_id                     = try(length(var.vpc_id) > 0, false) ? var.vpc_id : module.vpc[0].vpc_id
  subnets                    = try(length(var.vpc_id) > 0, false) ? var.private_subnet_ids : module.vpc[0].private_subnets
  security_groups            = [module.lb_int_sg.security_group_id]
  drop_invalid_header_fields = true

  access_logs = var.enable_bucket_logging ? {
    bucket  = try(length(var.log_bucket) > 0, false) ? var.log_bucket : module.log_bucket[0].s3_bucket_id
    prefix  = "lb"
    enabled = true
  } : { bucket = "", enabled = false }

  target_groups = [for target in local.targets : merge(target, { name = "${local.lb_name}-int-${target["name"]}" })]

  http_tcp_listeners = [
    {
      action_type = "redirect"
      port        = 80
      protocol    = "HTTP"
      action_type = "fixed-response"
      fixed_response = {
        status_code  = 204
        message_body = "No content. Try other endpoints for the URL: /jupyter, /notebook, /grok_compute."
        content_type = "text/plain"
      }
    },
    {
      port               = 5005
      protocol           = "HTTP"
      target_group_index = 5
    },
    {
      port               = 54321
      protocol           = "HTTP"
      target_group_index = 6
    }
  ]

  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
      priority                = 1
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [
        {
          path_patterns = ["/grok_compute/*"]
        }
      ]
    },
    {
      http_tcp_listener_index = 0
      priority                = 2
      actions = [
        {
          type               = "forward"
          target_group_index = 2
        }
      ]
      conditions = [
        {
          path_patterns = ["/jupyter/helper/*"]
        }
      ]
    },
    {
      http_tcp_listener_index = 0
      priority                = 3
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]
      conditions = [
        {
          path_patterns = ["/jupyter/*"]
        }
      ]
    },
    {
      http_tcp_listener_index = 0
      priority                = 4
      actions = [
        {
          type               = "forward"
          target_group_index = 4
        }
      ]
      conditions = [
        {
          path_patterns = ["/notebook/helper/*"]
        }
      ]
    },
    {
      http_tcp_listener_index = 0
      priority                = 5
      actions = [
        {
          type               = "forward"
          target_group_index = 3
        }
      ]
      conditions = [
        {
          path_patterns = ["/notebook/*"]
        }
      ]
    },
  ]

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "external" {
  count             = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  name              = "/aws/route53/${aws_route53_zone.external[0].name}"
  retention_in_days = 7
  kms_key_id        = var.custom_kms_key ? (try(length(var.kms_key) > 0, false) ? var.kms_key : module.kms[0].key_arn) : null
}

data "aws_iam_policy_document" "external" {
  count = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [aws_cloudwatch_log_group.external[0].arn]
    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "external" {
  count           = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  policy_document = data.aws_iam_policy_document.external[0].json
  policy_name     = "${var.name}-${var.environment}-route53"
}

resource "aws_route53_query_log" "external" {
  count                    = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  depends_on               = [aws_cloudwatch_log_resource_policy.external]
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.external[0].arn
  zone_id                  = aws_route53_zone.external[0].zone_id
}

resource "aws_cloudwatch_log_group" "internal" {
  count             = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  name              = "/aws/route53/${aws_route53_zone.internal[0].name}"
  retention_in_days = 7
  kms_key_id        = var.custom_kms_key ? (try(length(var.kms_key) > 0, false) ? var.kms_key : module.kms[0].key_arn) : null
}

data "aws_iam_policy_document" "internal" {
  count = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [aws_cloudwatch_log_group.internal[0].arn]
    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "internal" {
  count           = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  policy_document = data.aws_iam_policy_document.internal[0].json
  policy_name     = "${var.name}-${var.environment}-route53-internal"
}

resource "aws_route53_query_log" "internal" {
  count                    = var.route53_enabled && var.enable_route53_logging ? 1 : 0
  depends_on               = [aws_cloudwatch_log_resource_policy.internal]
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.internal[0].arn
  zone_id                  = aws_route53_zone.external[0].zone_id
}

resource "aws_route53_record" "external" {
  count   = var.route53_enabled ? 1 : 0
  zone_id = var.create_route53_external_zone ? aws_route53_zone.external[0].id : data.aws_route53_zone.external[0].id
  name    = local.r53_record
  type    = "A"
  alias {
    name                   = module.lb_ext.lb_dns_name
    zone_id                = module.lb_ext.lb_zone_id
    evaluate_target_health = true
  }
}
resource "aws_route53_zone" "internal" {
  count = var.create_route53_internal_zone ? 1 : 0
  name  = "datagrok.internal"
  tags  = local.tags
}
resource "aws_route53_record" "internal" {
  zone_id = var.create_route53_internal_zone ? aws_route53_zone.internal[0].id : var.route53_internal_zone
  name    = "cvm.datagrok.internal"
  type    = "A"
  alias {
    name                   = module.lb_int.lb_dns_name
    zone_id                = module.lb_int.lb_zone_id
    evaluate_target_health = true
  }
}
