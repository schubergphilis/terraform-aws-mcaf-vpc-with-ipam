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
  source  = "schubergphilis/mcaf-security-group/aws"
  version = "~> 0.1"

  description = "VPC endpoint security group"
  name_prefix = "vpc-endpoints-"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    ingress_https = {
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "HTTPS from VPC"
      from_port   = 443
      ip_protocol = "tcp"
      to_port     = 443
    }
  }
}

module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  endpoints          = local.endpoints
  security_group_ids = [module.security_group.id]
  subnet_ids         = module.vpc.subnet_ids["private"]
  vpc_id             = module.vpc.vpc_id
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
