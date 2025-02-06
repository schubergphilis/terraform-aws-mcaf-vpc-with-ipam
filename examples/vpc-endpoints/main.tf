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

module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  security_group_description = "VPC endpoint security group"
  security_group_name_prefix = "vpc-endpoints-"
  subnet_ids                 = module.vpc.subnet_ids["private"]
  vpc_id                     = module.vpc.vpc_id

  security_group_ingress_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  endpoints = {
    s3 = {
      service = "s3"
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpc.route_table_ids["private"]
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
    },
    ecs = {
      service = "ecs"
    },
    ecr_api = {
      service = "ecr.api"
    }
  }
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
