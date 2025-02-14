locals {
  endpoints = {
    snowflake = {
      service_full_name = "com.amazonaws.vpce.eu-central-1.vpce-svc-01234567891234567"
      private_link_dns_options = {
        dns_zone = "privatelink.snowflakecomputing.com"
        dns_record_names = [
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

module "vpc_endpoint" {
  source = "../../modules/vpc-endpoint"

  for_each = local.endpoints

  auto_accept              = lookup(each.value, "auto_accept", false)
  centralized_endpoint     = lookup(each.value, "centralized_endpoint", false)
  dns_options              = lookup(each.value, "dns_options", {})
  ip_address_type          = lookup(each.value, "ip_address_type", null)
  policy                   = lookup(each.value, "policy", null)
  private_dns_enabled      = lookup(each.value, "private_dns_enabled", true)
  private_link_dns_options = lookup(each.value, "private_link_dns_options", {})
  route_table_ids          = lookup(each.value, "route_table_ids", [])
  service                  = lookup(each.value, "service", null)
  service_full_name        = lookup(each.value, "service_full_name", null)
  service_region           = lookup(each.value, "service_region", null)
  type                     = lookup(each.value, "type", "Interface")

  security_group_ids = [module.security_group.id]
  subnet_ids         = module.vpc.subnet_ids["private"]
  vpc_id             = module.vpc.vpc_id
}
