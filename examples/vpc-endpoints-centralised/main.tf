locals {
  endpoints = [
    "access-analyzer",
    "acm-pca",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
  ]

  endpoints_map = { for endpoint in local.endpoints : endpoint => {
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

module "hub_vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  endpoints                  = local.endpoints_map
  security_group_description = "VPC endpoint security group"
  security_group_name_prefix = "hub-vpc-endpoints-"
  subnet_ids                 = module.hub_vpc.subnet_ids["private"]
  vpc_id                     = module.hub_vpc.vpc_id

  security_group_ingress_rules = {
    spoke_vpcs = {
      description = "Allow access from all spoke VPCs"
      cidr_ipv4   = "10.64.0.0/12"
    }
  }
}
