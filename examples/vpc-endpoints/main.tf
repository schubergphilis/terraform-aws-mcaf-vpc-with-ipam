locals {
  endpoints = {
    s3 = {
      service = "s3"
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
    },
    dynamodb = {
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      route_table_ids = module.vpc.route_table_ids["private"]
      service         = "dynamodb"
      type            = "Gateway"
    },
    ecs = {
      service = "ecs"
    },
    ecr_api = {
      service = "ecr.api"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "default" {}

module "vpc" {
  providers = { aws = aws, aws.transit_gateway_account = aws }
  source    = "../.."

  name               = "vpc"
  availability_zones = data.aws_availability_zones.default.names
  aws_vpc_ipam_pool  = "ipam-pool-1a1a1a1a1a1a1a1a1"
  vpc_cidr_netmask   = 20

  networks = [
    {
      name         = "public"
      cidr_netmask = 24
      public       = true
      nat_gw       = true
    },
    {
      name         = "private"
      cidr_netmask = 23
    }
  ]
}

module "security_group" {
  source = "schubergphilis/mcaf-security-group/aws"

  description = "VPC endpoint security group"
  name_prefix = "vpc-endpoints-"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }
}

module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  for_each = local.endpoints

  auto_accept              = lookup(each.value, "auto_accept", null)
  centralized_endpoint     = lookup(each.value, "centralized_endpoint", null)
  dns_options              = lookup(each.value, "dns_options", null)
  ip_address_type          = lookup(each.value, "ip_address_type", null)
  policy                   = lookup(each.value, "policy", null)
  private_dns_enabled      = lookup(each.value, "private_dns_enabled", null)
  private_link_dns_options = lookup(each.value, "private_link_dns_options", null)
  route_table_ids          = lookup(each.value, "route_table_ids", null)
  security_group_ids       = [module.security_group.id]
  service                  = lookup(each.value, "service", null)
  service_full_name        = lookup(each.value, "service_full_name", null)
  service_region           = lookup(each.value, "service_region", null)
  subnet_ids               = module.vpc.subnet_ids["private"]
  type                     = lookup(each.value, "type", null)
  vpc_id                   = module.vpc.vpc_id
}

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpc"

      values = [module.vpc.vpc_id]
    }
  }
}
