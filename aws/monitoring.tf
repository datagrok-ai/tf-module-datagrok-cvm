module "sns_topic" {
  source            = "registry.terraform.io/terraform-aws-modules/sns/aws"
  version           = "~> 3.3.0"
  create_sns_topic  = var.monitoring.alarms_enabled && var.monitoring.email_alerts && var.monitoring.create_sns_topic || var.monitoring.email_alerts_datagrok
  name              = local.sns_topic_name
  display_name      = "Datagrok SNS topic"
  kms_master_key_id = local.create_kms ? module.kms[0].key_id : null
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.monitoring.alarms_enabled && var.monitoring.email_alerts || var.monitoring.email_alerts_datagrok ? toset(
    compact(
      concat(
        var.monitoring.email_alerts_datagrok ?
        ["monitoring@datagrok.ai", "spodolskaya@datagrok.ai", "dnahovskyi@datagrok.ai"] :
        [],
        var.monitoring.email_alerts ? var.monitoring.email_recipients : []
      )
    )
  ) : []
  topic_arn = var.monitoring.create_sns_topic ? module.sns_topic.sns_topic_arn : var.monitoring.sns_topic_arn
  protocol  = "email"
  endpoint  = each.key
}

# Encrypt the URL, storing encryption here will show it in logs and in tfstate
# https://www.terraform.io/docs/state/sensitive-data.html
resource "aws_kms_ciphertext" "slack_url" {
  count     = var.monitoring.alarms_enabled && var.monitoring.slack_alerts && local.create_kms ? 1 : 0
  plaintext = var.monitoring.slack_webhook_url
  key_id    = local.create_kms ? module.kms[0].key_id : null
}

module "notify_slack" {
  source  = "registry.terraform.io/terraform-aws-modules/notify-slack/aws"
  version = "~> 5.4.0"

  create               = var.monitoring.alarms_enabled && var.monitoring.slack_alerts
  sns_topic_name       = local.sns_topic_name
  sns_topic_kms_key_id = local.create_kms ? module.kms[0].key_id : null
  sns_topic_tags       = local.tags
  kms_key_arn          = local.create_kms ? module.kms[0].key_id : null
  slack_webhook_url    = local.create_kms ? aws_kms_ciphertext.slack_url[0].ciphertext_blob : var.monitoring.slack_webhook_url
  slack_channel        = var.monitoring.slack_channel
  slack_username       = var.monitoring.slack_username
  slack_emoji          = var.monitoring.slack_emoji
}

resource "aws_cloudwatch_metric_alarm" "jkg_task_count" {
  count               = var.monitoring.alarms_enabled && var.ecs_cluster_insights ? 1 : 0
  alarm_name          = "${local.ecs_name}-jkg-task-count"
  comparison_operator = "LessThanThreshold"
  threshold           = "1"
  evaluation_periods  = "2"
  treat_missing_data  = "ignore"
  alarm_description   = "This metric monitors ${local.ecs_name} Jupyter Kernel Gateway ECS tasks count"
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags

  metric_query {
    id          = "expression"
    expression  = "IF(desired > running, 0, 1)"
    label       = "Task Failures"
    return_data = "true"
  }

  metric_query {
    id = "desired"

    metric {
      metric_name = "DesiredTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Average"
      dimensions = {
        ClusterName = module.ecs.cluster_name
        ServiceName = aws_ecs_service.jkg.name
      }
    }
  }

  metric_query {
    id = "running"

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Average"
      dimensions = {
        ClusterName = module.ecs.cluster_name
        ServiceName = aws_ecs_service.jkg.name
      }
    }
  }
}
resource "aws_cloudwatch_metric_alarm" "jn_task_count" {
  count               = var.monitoring.alarms_enabled && var.ecs_cluster_insights ? 1 : 0
  alarm_name          = "${local.ecs_name}-jn-task-count"
  comparison_operator = "LessThanThreshold"
  threshold           = "1"
  evaluation_periods  = "2"
  treat_missing_data  = "ignore"
  alarm_description   = "This metric monitors ${local.ecs_name} Jupyter Notebook ECS tasks count"
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags

  metric_query {
    id          = "expression"
    expression  = "IF(desired > running, 0, 1)"
    label       = "Task Failures"
    return_data = "true"
  }

  metric_query {
    id = "desired"

    metric {
      metric_name = "DesiredTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Average"
      dimensions = {
        ClusterName = module.ecs.cluster_name
        ServiceName = aws_ecs_service.jn.name
      }
    }
  }

  metric_query {
    id = "running"

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Average"
      dimensions = {
        ClusterName = module.ecs.cluster_name
        ServiceName = aws_ecs_service.jn.name
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_count" {
  count               = var.monitoring.alarms_enabled && var.ecs_cluster_insights && var.ecs_launch_type == "EC2" ? 1 : 0
  alarm_name          = "${local.ecs_name}-ec2-instance-count"
  comparison_operator = "LessThanThreshold"
  threshold           = "1"
  evaluation_periods  = "1"
  metric_name         = "ContainerInstanceCount"
  namespace           = "ECS/ContainerInsights"
  dimensions = {
    ClusterName = module.ecs.cluster_name
  }
  period             = "60"
  statistic          = "Average"
  treat_missing_data = "ignore"
  alarm_description  = "${local.ecs_name} ECS EC2 instances count alarm"
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = var.monitoring.alarms_enabled ? 1 : 0
  alarm_name          = "${local.ecs_name}-ecs-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = "60"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  treat_missing_data  = "ignore"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "${local.ecs_name} ECS cluster CPU capacity alarm"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  dimensions = {
    ClusterName = module.ecs.cluster_name
  }
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "high_ram" {
  count               = var.monitoring.alarms_enabled ? 1 : 0
  alarm_name          = "${local.ecs_name}-ecs-high-ram"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = "60"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  treat_missing_data  = "ignore"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "${local.ecs_name} ECS cluster RAM capacity alarm"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  dimensions = {
    ClusterName = module.ecs.cluster_name
  }
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lb_target" {
  for_each            = var.monitoring.alarms_enabled ? local.targets : {}
  alarm_name          = "datagrok-lb-target-${module.lb_ext.target_groups[each.key].name}"
  comparison_operator = "LessThanThreshold"
  threshold           = "1"
  alarm_description   = "${local.ecs_name} external ALB target group ${module.lb_ext.target_groups[each.key].name} registered targets alarms"
  treat_missing_data  = "ignore"
  period              = "60"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  statistic           = "Average"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  dimensions = {
    TargetGroup  = module.lb_ext.target_groups[each.key].arn_suffix
    LoadBalancer = module.lb_ext.arn_suffix
  }
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "datagrok_lb_5xx_count" {
  count               = var.monitoring.alarms_enabled ? 1 : 0
  alarm_name          = "${local.lb_name}-datagrok-lb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "${local.lb_name} external ALB 5XX error code count is too high"
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    "LoadBalancer" = module.lb_ext.arn_suffix
  }
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lb_target_5xx_count" {
  for_each               = var.monitoring.alarms_enabled ? local.targets : {}
  alarm_name          = "datagrok-lb-target-${module.lb_ext.target_groups[each.key].name}-5xx"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "0"
  alarm_description   = "${local.ecs_name} external ALB target group ${module.lb_ext.target_groups[each.key].name} registered 5XX errors"
  treat_missing_data  = "notBreaching"
  period              = "120"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  statistic           = "Sum"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  dimensions = {
    TargetGroup  = module.lb_ext.target_groups[each.key].arn_suffix
    LoadBalancer = module.lb_ext.arn_suffix
  }
  alarm_actions = compact([
    var.monitoring.slack_alerts ?
    module.notify_slack.slack_topic_arn :
    "",
    var.monitoring.email_alerts ?
    module.sns_topic.sns_topic_arn :
    "",
    !var.monitoring.create_sns_topic ?
    var.monitoring.sns_topic_arn :
    ""
  ])
  tags = local.tags
}
