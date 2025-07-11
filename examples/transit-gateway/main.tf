provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "default" {}

module "transit_gateway" {
  source  = "schubergphilis/mcaf-transit-gateway/aws"
  version = "~> 0.6"

  name                                           = "transit-gateway"
  description                                    = "production transit gateway"
  route_tables                                   = ["shared", "vpc"]
  transit_gateway_auto_accept_shared_attachments = true

  tags = {
    env = "production"
  }
}

module "vpc" {
  providers = { aws = aws, aws.transit_gateway_account = aws }
  source    = "../.."

  name                                    = "vpc"
  availability_zones                      = data.aws_availability_zones.default.names
  aws_vpc_ipam_pool                       = "ipam-pool-1a1a1a1a1a1a1a1a1"
  transit_gateway_id                      = module.transit_gateway.transit_gateway_id
  transit_gateway_route_table_association = module.transit_gateway.transit_gateway_route_table_id["vpc"]
  transit_gateway_route_table_propagation = { shared = module.transit_gateway.transit_gateway_route_table_id["shared"] }
  vpc_cidr_netmask                        = 20

  networks = [
    {
      name           = "peering"
      cidr_netmask   = 28
      tgw_attachment = true
    },
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
