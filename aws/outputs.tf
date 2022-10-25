output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(module.vpc[0].vpc_id, var.vpc_id)
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(module.vpc[0].vpc_cidr_block, var.cidr)
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = try(module.vpc[0].private_subnets, var.private_subnet_ids)
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = try(module.vpc[0].public_subnets, var.public_subnet_ids)
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = try(module.vpc[0].database_subnets, var.data_subnet_ids)
}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = try(module.vpc[0].database_subnet_group, var.database_subnet_group)
}

output "vpc_flow_log_id" {
  description = "The ID of the Flow Log resource"
  value       = try(module.vpc[0].vpc_flow_log_id, "")
}

output "vpc_flow_log_destination_arn" {
  description = "The ARN of the destination for VPC Flow Logs"
  value       = try(module.vpc[0].vpc_flow_log_destination_arn, "")
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log group"
  value       = try(aws_cloudwatch_log_group.ecs[0].name, var.cloudwatch_log_group_name)
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Log group"
  value       = try(aws_cloudwatch_log_group.ecs[0].arn, var.cloudwatch_log_group_arn)
}

output "log_bucket" {
  description = "The ID of the S3 bucket for logs"
  value       = try(module.log_bucket.s3_bucket_id, var.log_bucket)
}

output "service_discovery_namespace" {
  description = "The ID of the CloudMap for Datagrok"
  value       = try(aws_service_discovery_private_dns_namespace.datagrok[0].id, "")
}

output "route_53_external_zone" {
  description = "The ID of the Route53 public zone for Datagrok"
  value       = try(aws_route53_record.external[0].zone_id, "")
}

output "route_53_internal_zone" {
  description = "The ID of the Route53 internal zone for Datagrok"
  value       = try(aws_route53_record.internal.zone_id, var.route53_internal_zone)
}
