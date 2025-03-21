resource "aws_cloudwatch_log_group" "ecs" {
  count             = var.create_cloudwatch_log_group ? 1 : 0
  name              = "/aws/ecs/${local.full_name}"
  retention_in_days = 7
  #checkov:skip=CKV_AWS_158:The KMS key is configurable
  kms_key_id = var.custom_kms_key ? try(module.kms[0].key_arn, var.kms_key) : null
  tags       = local.tags
}
module "sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.12.0"

  name        = local.ecs_name
  description = "${local.ecs_name} Datagrok ECS Security Group"
  vpc_id      = try(module.vpc[0].vpc_id, var.vpc_id)

  egress_with_cidr_blocks = var.egress_rules
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "Access from within Security Group. Internal communications."
      cidr_blocks = try(module.vpc[0].vpc_cidr_block, var.cidr)
    },
  ]
}
module "ecs" {
  source  = "registry.terraform.io/terraform-aws-modules/ecs/aws"
  version = "~> 4.1.1"

  cluster_name = local.ecs_name

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name     = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
        cloud_watch_encryption_enabled = var.custom_kms_key
      }
    }
  }

  cluster_settings = {
    name  = "containerInsights"
    value = var.ecs_cluster_insights ? "enabled" : "disabled"
  }

  tags = local.tags
}

resource "aws_secretsmanager_secret" "docker_hub" {
  count       = try(var.docker_hub_credentials.create_secret, false) && !var.ecr_enabled && var.ecs_launch_type != "FARGATE" ? 1 : 0
  name_prefix = "${local.full_name}_docker_hub"
  description = "Docker Hub token to download images"
  #checkov:skip=CKV_AWS_149:The KMS key is configurable
  kms_key_id              = var.custom_kms_key ? try(module.kms[0].key_arn, var.kms_key) : null
  recovery_window_in_days = 7
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "docker_hub" {
  count     = try(var.docker_hub_credentials.create_secret, false) && !var.ecr_enabled && var.ecs_launch_type != "FARGATE" ? 1 : 0
  secret_id = aws_secretsmanager_secret.docker_hub[0].id
  secret_string = jsonencode({
    "username" : sensitive(var.docker_hub_credentials.user),
    "password" : sensitive(var.docker_hub_credentials.password)
  })
}

resource "aws_ecr_repository" "ecr" {
  for_each             = var.ecr_enabled ? local.images : {}
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  force_delete         = !var.termination_protection
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.custom_kms_key ? try(module.kms[0].key_arn, var.kms_key) : null
  }
  image_scanning_configuration {
    scan_on_push = var.ecr_image_scan_on_push
  }
  tags = local.tags
}

resource "aws_ecr_repository_policy" "ecr" {
  for_each   = var.ecr_enabled && var.ecr_principal_restrict_access ? local.images : {}
  repository = aws_ecr_repository.ecr[each.key].name
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = concat([data.aws_caller_identity.current.arn], var.ecr_policy_principal)
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  })
}

resource "null_resource" "ecr_push" {
  for_each = var.ecr_enabled ? local.images : {}
  triggers = {
    tag   = each.value["tag"]
    image = each.value["image"]
  }

  provisioner "local-exec" {
    command     = "${path.module}/ecr_push.sh --tag ${each.value["tag"]} --image ${each.value["image"]} --ecr ${aws_ecr_repository.ecr[each.key].repository_url}"
    interpreter = ["bash", "-c"]
  }

  depends_on = [aws_ecr_repository.ecr]
}

resource "aws_iam_policy" "exec" {
  name        = "${local.ecs_name}_exec"
  description = "Datagrok execution policy for ECS task"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Action" = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect" = "Allow",
        "Resource" = compact([
          var.create_cloudwatch_log_group ? aws_cloudwatch_log_group.ecs[0].arn : var.cloudwatch_log_group_arn,
          "${var.create_cloudwatch_log_group ? aws_cloudwatch_log_group.ecs[0].arn : var.cloudwatch_log_group_arn}:log-stream:*"
        ])
      }
    ]
  })
}

resource "aws_iam_policy" "ecr" {
  count       = var.ecr_enabled ? 1 : 0
  name        = "${local.ecs_name}_ecr"
  description = "Datagrok ECR pull policy for ECS task"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Action" : "ecr:GetAuthorizationToken",
        "Condition" = {},
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ],
        "Condition" = {},
        "Effect"    = "Allow",
        "Resource" = toset([
          for ecr in aws_ecr_repository.ecr : ecr.arn
        ])
      }
    ]
  })
}

resource "aws_iam_policy" "docker_hub" {
  count       = !var.ecr_enabled && var.ecs_launch_type != "FARGATE" ? 1 : 0
  name        = "${local.ecs_name}_docker_hub"
  description = "Datagrok Docker Hub credentials policy for ECS task"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = concat([
      {
        Action    = ["secretsmanager:GetSecretValue"],
        Condition = {},
        Effect    = "Allow",
        Resource = [
          try(aws_secretsmanager_secret.docker_hub[0].arn, var.docker_hub_credentials.secret_arn)
        ]
      }],
      var.custom_kms_key ? [{
        Action    = ["kms:Decrypt"],
        Condition = {},
        Effect    = "Allow",
        Resource = [
          try(module.kms[0].key_arn, var.kms_key)
        ]
      }] : []
    )
  })
}
resource "aws_iam_role" "exec" {
  name = "${local.ecs_name}_exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
        }
      },
    ]
  })
  managed_policy_arns = compact([
    aws_iam_policy.exec.arn,
    var.ecr_enabled ? aws_iam_policy.ecr[0].arn : (var.ecs_launch_type == "FARGATE" ? "" : aws_iam_policy.docker_hub[0].arn)
  ])

  tags = local.tags
}
resource "aws_iam_role" "task" {
  name = "${local.ecs_name}_task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
        }
      },
    ]
  })
  managed_policy_arns = compact(concat([
    aws_iam_policy.exec.arn,
    var.ecr_enabled ? aws_iam_policy.ecr[0].arn : (var.ecs_launch_type == "FARGATE" ? "" : aws_iam_policy.docker_hub[0].arn)
  ], var.task_iam_policies))

  tags = local.tags
}


data "aws_secretsmanager_secret" "jkg_secret" {
  name = var.jkg_secret
}
data "aws_secretsmanager_secret_version" "jkg_secret" {
  secret_id = data.aws_secretsmanager_secret.jkg_secret.id
}

resource "aws_ecs_task_definition" "jkg" {
  depends_on = [null_resource.ecr_push]
  family     = "${local.ecs_name}_jupyter_kernel_gateway"

  container_definitions = jsonencode([
    {
      name = "resolv_conf"
      command = [
        "${data.aws_region.current.name}.compute.internal",
        "datagrok.${var.name}.${var.environment}.internal",
        "datagrok.${var.name}.${var.environment}.cn.internal"
      ]
      essential = false
      image     = "${var.ecr_enabled ? aws_ecr_repository.ecr["ecs-searchdomain-sidecar-${var.name}-${var.environment}"].repository_url : local.images["ecs-searchdomain-sidecar-${var.name}-${var.environment}"]["image"]}:${local.images["ecs-searchdomain-sidecar-${var.name}-${var.environment}"]["tag"]}"
      logConfiguration = {
        LogDriver = "awslogs",
        Options = {
          awslogs-group         = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jupyter_kernel_gateway"
        }
      }
      memoryReservation = 100
    },
    merge({
      name  = "jupyter_kernel_gateway"
      image = "${var.ecr_enabled ? aws_ecr_repository.ecr["jupyter_kernel_gateway"].repository_url : var.docker_jkg_image}:${var.ecr_enabled ? local.images["jupyter_kernel_gateway"]["tag"] : var.docker_jkg_tag}"
      dependsOn = [
        {
          "condition" : "SUCCESS",
          "containerName" : "resolv_conf"
        }
      ]
      essential = true
      environment = [
        {
          name = "GROK_PARAMETERS",
          value = jsonencode(
            {
              jupyterToken : jsondecode(data.aws_secretsmanager_secret_version.jkg_secret.secret_string)["token"]
              capabilities : ["jupyter"]
              isolatesCount: var.jkgIsolatesCount,
              queuePluginSettings = {
                amqpHost = "rabbitmq.datagrok-${var.environment}.local"
                amqpPassword = var.rabbitmq_password
                amqpPort     = var.amqpPort
                amqpUser     = var.rabbitmq_username
                tls = var.amqpTLS
                pipeHost     = "grok_pipe.datagrok.${split("-",var.name)[0]}.${var.environment}.internal"
                pipeKey      = var.pipeKey
                maxConcurrentCalls = 4
              }
            })
        }
      ]
      logConfiguration = {
        LogDriver = "awslogs",
        Options = {
          awslogs-group         = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jupyter_kernel_gateway"
        }
      }
      portMappings = [
        {
          containerPort = 5005
          hostPort      = var.ecs_launch_type == "FARGATE" ? 5005 : 0
        },
        {
          containerPort = 8888
          hostPort      = var.ecs_launch_type == "FARGATE" ? 8888 : 0
        },
      ]
      memoryReservation = var.ecs_launch_type == "FARGATE" ? var.jkg_memory - 200 : var.jkg_container_memory_reservation
      cpu               = var.jkg_container_cpu
      }, var.ecr_enabled ? {} : (var.ecs_launch_type == "FARGATE" ? {} : {
        repositoryCredentials = {
          credentialsParameter = try(aws_secretsmanager_secret.docker_hub[0].arn, var.docker_hub_credentials.secret_arn)
        }
      }), var.gpu_enabled ? {
      resourceRequirements = [{ type = "GPU", value = "1" }]
      } : {}
    )
  ])

  dynamic "ephemeral_storage" {
    for_each = var.ecs_launch_type == "FARGATE" ? [
      {
        size_in_gib : 50
      }
    ] : []
    content {
      size_in_gib = ephemeral_storage.value["size_in_gib"]
    }
  }

  cpu                      = var.ecs_launch_type == "FARGATE" ? var.jkg_cpu : null
  memory                   = var.ecs_launch_type == "FARGATE" ? var.jkg_memory : null
  network_mode             = var.ecs_launch_type == "FARGATE" ? "awsvpc" : "bridge"
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn
  requires_compatibilities = [var.ecs_launch_type]
}
resource "aws_ecs_task_definition" "jn" {
  depends_on = [null_resource.ecr_push]
  family     = "${local.ecs_name}_jupyter_notebook"

  container_definitions = jsonencode([
    {
      name = "resolv_conf"
      command = [
        "${data.aws_region.current.name}.compute.internal",
        "datagrok.${var.name}.${var.environment}.internal",
        "datagrok.${var.name}.${var.environment}.cn.internal"
      ]
      essential = false
      image     = "${var.ecr_enabled ? aws_ecr_repository.ecr["ecs-searchdomain-sidecar-${var.name}-${var.environment}"].repository_url : local.images["ecs-searchdomain-sidecar-${var.name}-${var.environment}"]["image"]}:${local.images["ecs-searchdomain-sidecar-${var.name}-${var.environment}"]["tag"]}"
      logConfiguration = {
        LogDriver = "awslogs",
        Options = {
          awslogs-group         = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jupyter_notebook"
        }
      }
      memoryReservation = 100
    },
    merge({
      name  = "jupyter_notebook"
      image = "${var.ecr_enabled ? aws_ecr_repository.ecr["jupyter_notebook"].repository_url : var.docker_jn_image}:${var.ecr_enabled ? local.images["jupyter_notebook"]["tag"] : var.docker_jn_tag}"
      dependsOn = [
        {
          "condition" : "SUCCESS",
          "containerName" : "resolv_conf"
        }
      ]
      essential = true
      logConfiguration = {
        LogDriver = "awslogs",
        Options = {
          awslogs-group         = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jupyter_notebook"
        }
      }
      portMappings = [
        {
          containerPort = 5005
          hostPort      = var.ecs_launch_type == "FARGATE" ? 5005 : 0
        },
        {
          containerPort = 8889
          hostPort      = var.ecs_launch_type == "FARGATE" ? 8889 : 0
        },
      ]
      memoryReservation = var.ecs_launch_type == "FARGATE" ? var.jn_memory - 200 : var.jn_container_memory_reservation
      cpu               = var.jn_container_cpu
      }, var.ecr_enabled ? {} : (var.ecs_launch_type == "FARGATE" ? {} : {
        repositoryCredentials = {
          credentialsParameter = try(aws_secretsmanager_secret.docker_hub[0].arn, var.docker_hub_credentials.secret_arn)
        }
    }))
  ])
  cpu                      = var.ecs_launch_type == "FARGATE" ? var.jn_cpu : null
  memory                   = var.ecs_launch_type == "FARGATE" ? var.jn_memory : null
  network_mode             = var.ecs_launch_type == "FARGATE" ? "awsvpc" : "bridge"
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn
  requires_compatibilities = [var.ecs_launch_type]
}
resource "aws_service_discovery_private_dns_namespace" "datagrok" {
  count       = var.service_discovery_namespace.create && var.ecs_launch_type == "FARGATE" ? 1 : 0
  name        = "datagrok.${var.name}.${var.environment}.cn.internal"
  description = "Datagrok Service Discovery"
  vpc         = try(module.vpc[0].vpc_id, var.vpc_id)
}
resource "aws_service_discovery_service" "jkg" {
  count       = var.ecs_launch_type == "FARGATE" ? 1 : 0
  name        = "jupyter_kernel_gateway"
  description = "Datagrok CVM JKG service discovery entry"

  dns_config {
    namespace_id = var.service_discovery_namespace.create ? aws_service_discovery_private_dns_namespace.datagrok[0].id : var.service_discovery_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
resource "aws_service_discovery_service" "jn" {
  count       = var.ecs_launch_type == "FARGATE" ? 1 : 0
  name        = "jupyter_notebook"
  description = "Datagrok CVM JN service discovery entry"

  dns_config {
    namespace_id = var.service_discovery_namespace.create ? aws_service_discovery_private_dns_namespace.datagrok[0].id : var.service_discovery_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "jkg" {
  name            = "${local.ecs_name}_jupyter_kernel_gateway"
  cluster         = module.ecs.cluster_arn
  task_definition = aws_ecs_task_definition.jkg.arn
  launch_type     = var.ecs_launch_type

  desired_count                      = 1
  deployment_maximum_percent         = var.gpu_enabled ? 100 : 200
  deployment_minimum_healthy_percent = var.gpu_enabled ? 0 : 100
  scheduling_strategy                = "REPLICA"
  deployment_controller {
    type = "ECS"
  }
  enable_execute_command = true
  force_new_deployment   = true

  placement_constraints {
    expression = "attribute:type == 'cvm'"
    type       = "memberOf"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }


  dynamic "service_registries" {
    for_each = var.ecs_launch_type == "FARGATE" ? [
      {
        registry_arn : aws_service_discovery_service.jkg[0].arn
      }
    ] : []
    content {
      registry_arn = service_registries.value["registry_arn"]
    }
  }

  dynamic "network_configuration" {
    for_each = var.ecs_launch_type == "FARGATE" ? [
      {
        subnets : try(module.vpc[0].private_subnets, var.private_subnet_ids)
        security_groups : [module.sg.security_group_id]
      }
    ] : []
    content {
      subnets          = network_configuration.value["subnets"]
      security_groups  = network_configuration.value["security_groups"]
      assign_public_ip = false
    }
  }
}
resource "aws_ecs_service" "jn" {
  name            = "${local.ecs_name}_jupyter_notebook"
  cluster         = module.ecs.cluster_arn
  task_definition = aws_ecs_task_definition.jn.arn
  launch_type     = var.ecs_launch_type

  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  scheduling_strategy                = "REPLICA"
  deployment_controller {
    type = "ECS"
  }
  enable_execute_command = true
  force_new_deployment   = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "service_registries" {
    for_each = var.ecs_launch_type == "FARGATE" ? [
      {
        registry_arn : aws_service_discovery_service.jn[0].arn
      }
    ] : []
    content {
      registry_arn = service_registries.value["registry_arn"]
    }
  }

  load_balancer {
    target_group_arn = module.lb_ext.target_groups["jn"].arn
    container_name   = "jupyter_notebook"
    container_port   = 8889
  }
  load_balancer {
    target_group_arn = module.lb_ext.target_groups["jnH"].arn
    container_name   = "jupyter_notebook"
    container_port   = 5005
  }
  load_balancer {
    target_group_arn = module.lb_int.target_groups["jn"].arn
    container_name   = "jupyter_notebook"
    container_port   = 8889
  }
  load_balancer {
    target_group_arn = module.lb_int.target_groups["jnH"].arn
    container_name   = "jupyter_notebook"
    container_port   = 5005
  }

  dynamic "network_configuration" {
    for_each = var.ecs_launch_type == "FARGATE" ? [
      {
        subnets : try(module.vpc[0].private_subnets, var.private_subnet_ids)
        security_groups : [module.sg.security_group_id]
      }
    ] : []
    content {
      subnets          = network_configuration.value["subnets"]
      security_groups  = network_configuration.value["security_groups"]
      assign_public_ip = false
    }
  }
}
data "aws_ami" "aws_optimized_ecs" {
  count       = !try(length(var.ami_id) > 0, false) && var.ecs_launch_type == "EC2" ? 1 : 0
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs${var.gpu_enabled ? "-gpu" : ""}-hvm*ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["591542846629"] # AWS
}
resource "aws_key_pair" "ec2" {
  count      = var.ecs_launch_type == "EC2" && try(length(var.public_key) > 0, false) && !try(length(var.key_pair_name) > 0, false) ? 1 : 0
  key_name   = local.full_name
  public_key = var.public_key
}
resource "aws_iam_policy" "ec2" {
  name        = "${local.ec2_name}_ec2"
  description = "Datagrok execution policy for EC2 instance to run ECS tasks"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Action" = [
          "ec2:DescribeTags",
          "ecs:DiscoverPollEndpoint"
        ],
        "Effect"   = "Allow",
        "Resource" = "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:Poll",
          "ecs:StartTelemetrySession",
          "ecs:UpdateContainerInstancesState",
          "ecs:RegisterContainerInstance",
          "ecs:Submit*",
          "ecs:DeregisterContainerInstance"
        ],
        "Resource" : [
          module.ecs.cluster_arn,
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:container-instance/${module.ecs.cluster_name}/*"
        ]
      },
    ]
  })
}
resource "aws_iam_role" "ec2" {
  name = "${local.ec2_name}_ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ec2.amazonaws.com"]
        }
      },
    ]
  })
  managed_policy_arns = compact([
    aws_iam_policy.exec.arn,
    var.ecr_enabled ? aws_iam_policy.ecr[0].arn : (var.ecs_launch_type == "FARGATE" ? "" : aws_iam_policy.docker_hub[0].arn),
    aws_iam_policy.ec2.arn
  ])

  tags = local.tags
}
resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.ecs_launch_type == "EC2" ? 1 : 0
  name  = "${local.ec2_name}_ec2_profile"
  role  = aws_iam_role.ec2.name
}
resource "aws_instance" "ec2" {
  count         = var.ecs_launch_type == "EC2" ? 1 : 0
  ami           = try(data.aws_ami.aws_optimized_ecs[0].id, var.ami_id)
  instance_type = var.instance_type
  key_name      = try(aws_key_pair.ec2[0].key_name, var.key_pair_name)
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    ecs_cluster_name = module.ecs.cluster_name
    gpu_enabled      = var.gpu_enabled
  }))
  availability_zone                    = data.aws_availability_zones.available.names[0]
  subnet_id                            = var.ec2_public_access ? try(module.vpc[0].public_subnets[0], var.public_subnet_ids[0]) : try(module.vpc[0].private_subnets[0], var.private_subnet_ids[0])
  associate_public_ip_address          = var.ec2_public_access
  vpc_security_group_ids               = [module.sg.security_group_id]
  disable_api_stop                     = var.termination_protection
  disable_api_termination              = var.termination_protection
  source_dest_check                    = true
  instance_initiated_shutdown_behavior = "stop"
  iam_instance_profile                 = aws_iam_instance_profile.ec2_profile[0].name
  monitoring                           = var.ec2_detailed_monitoring_enabled
  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "optional"
    instance_metadata_tags = "enabled"
  }
  maintenance_options {
    auto_recovery = "default"
  }
  root_block_device {
    encrypted   = true
    kms_key_id  = var.custom_kms_key ? try(module.kms[0].key_arn, var.kms_key) : null
    volume_type = "gp3"
    throughput  = try(length(var.root_volume_throughput) > 0, false) ? var.root_volume_throughput : null
    volume_size = var.ec2_root_volume_size
  }
  ebs_optimized = true
  tags          = merge({ Name = local.ec2_name }, local.tags)

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
