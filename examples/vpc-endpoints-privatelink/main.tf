locals {
  endpoints = {
    snowflake = {
      service_full_name = "com.amazonaws.vpce.eu-central-1.vpce-svc-01234567891234567"
      private_link_dns_options = {
        dns_zone = "privatelink.snowflakecomputing.com"
        dns_records = [
          "app.eu-central-1",
          "app-abcdefg-aa_bb_cc",
        ]
      }
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
  version = "~> 2.0"

  description = "VPC endpoint security group"
  name_prefix = "vpc-endpoints-"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    ingress_https = {
      cidr_ipv4   = [module.vpc.vpc_cidr_block]
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
