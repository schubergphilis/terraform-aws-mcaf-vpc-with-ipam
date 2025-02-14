locals {
  endpoints_list = [
    "access-analyzer",
    "acm-pca",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
  ]

  endpoints = { for endpoint in local.endpoints_list : endpoint => {
    centralized_endpoint = true
    service              = endpoint
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "default" {}

module "hub_vpc" {
  providers = { aws = aws, aws.transit_gateway_account = aws }
  source    = "../.."

  name               = "hub-vpc"
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
  name_prefix = "hub-vpc-endpoints-"
  vpc_id      = module.hub_vpc.vpc_id

  ingress_rules = {
    spoke_vpcs = {
      description = "Allow access from all spoke VPCs"
      cidr_ipv4   = "10.64.0.0/12"
    }
  }
}

module "hub_vpc_endpoints" {
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
  subnet_ids               = module.hub_vpc.subnet_ids["private"]
  type                     = lookup(each.value, "type", null)
  vpc_id                   = module.hub_vpc.vpc_id
}
