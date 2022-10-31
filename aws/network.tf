module "vpc" {
  create_vpc = var.vpc_create
  source     = "registry.terraform.io/terraform-aws-modules/vpc/aws"
  version    = "~> 3.14.2"

  name = local.vpc_name

  azs  = slice(data.aws_availability_zones.available.names, 0, var.vpc_subnets_count)
  cidr = var.cidr

  public_subnets = [
    for zone in slice(data.aws_availability_zones.available.names, 0, var.vpc_subnets_count) :
    cidrsubnet(var.cidr, 7, index(data.aws_availability_zones.available.names, zone) + 1)
  ]
  private_subnets = [
    for zone in slice(data.aws_availability_zones.available.names, 0, var.vpc_subnets_count) :
    cidrsubnet(var.cidr, 7, index(data.aws_availability_zones.available.names, zone) + 11)
  ]
  database_subnets = [
    for zone in slice(data.aws_availability_zones.available.names, 0, var.vpc_subnets_count) :
    cidrsubnet(var.cidr, 7, index(data.aws_availability_zones.available.names, zone) + 21)
  ]

  enable_ipv6                            = false
  create_igw                             = true
  enable_nat_gateway                     = true
  single_nat_gateway                     = var.vpc_single_nat_gateway
  one_nat_gateway_per_az                 = false
  map_public_ip_on_launch                = true
  create_database_subnet_group           = true
  create_database_subnet_route_table     = false
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false
  enable_dns_hostnames                   = true
  enable_dns_support                     = true

  enable_flow_log                                 = var.enable_flow_logs
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_cloudwatch_log_group_name_prefix       = var.flow_log_cloudwatch_log_group_name_prefix
  flow_log_file_format                            = "plain-text"
  flow_log_log_format                             = var.flow_log_log_format
  flow_log_cloudwatch_log_group_retention_in_days = 7
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60

  tags = local.tags
}
