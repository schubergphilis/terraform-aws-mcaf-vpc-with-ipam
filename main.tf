locals {
  networks = flatten([
    for i, network in var.networks : [
      for az in var.availability_zones : {
        availability_zone = az
        key               = "${network.name}_${az}"
        name              = network.name
        nat_gw            = network.nat_gw
        new_bits          = network.cidr_netmask - var.vpc_cidr_netmask
        public            = network.public
        tgw_attachment    = network.tgw_attachment
        tags              = network.tags
      }
    ]]
  )

  cidr_subnets = cidrsubnets(aws_vpc_ipam_preview_next_cidr.vpc.cidr, local.networks[*].new_bits...)

  vpc_subnets = [for i, n in local.networks : {
    availability_zone = n.availability_zone
    cidr_block        = n.key != null ? local.cidr_subnets[i] : tostring(null)
    key               = n.key
    name              = n.name
    nat_gw            = n.nat_gw
    public            = n.public
    tgw_attachment    = n.tgw_attachment
    tags              = n.tags
  }]
}

resource "aws_vpc_ipam_preview_next_cidr" "vpc" {
  ipam_pool_id   = var.aws_vpc_ipam_pool
  netmask_length = var.vpc_cidr_netmask
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "default" {
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true
  ipv4_ipam_pool_id                    = var.aws_vpc_ipam_pool
  ipv4_netmask_length                  = var.vpc_cidr_netmask

  tags = merge({ "Name" = var.name }, var.tags)
}

resource "aws_default_security_group" "workload_vpc" {
  vpc_id = aws_vpc.default.id
}

################################################################################
# Subnets
################################################################################

resource "aws_subnet" "default" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet }

  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = each.value.public ? true : false
  vpc_id                  = aws_vpc.default.id

  tags = merge(var.tags, each.value.tags, { "Name" = each.key })
}

resource "aws_route_table" "default" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet }

  vpc_id = aws_vpc.default.id

  tags = merge({ "Name" = each.key }, var.tags)
}

resource "aws_route_table_association" "default" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet }

  subnet_id      = aws_subnet.default[each.key].id
  route_table_id = aws_route_table.default[each.key].id
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "default" {
  count = anytrue(var.networks[*].public) ? 1 : 0

  vpc_id = aws_vpc.default.id

  tags = merge({ "Name" = var.name }, var.tags)
}

resource "aws_route" "internet_gateway" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet if subnet.public }

  route_table_id         = aws_route_table.default[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default[0].id
}

################################################################################
# NAT Gateway
################################################################################

resource "aws_eip" "nat_gw" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet if subnet.nat_gw }

  domain = "vpc"

  tags = merge({ "Name" = "nat-gw_${each.key}" }, var.tags)
}

resource "aws_nat_gateway" "public" {
  for_each = { for subnet in local.vpc_subnets : subnet.key => subnet if subnet.nat_gw }

  allocation_id = aws_eip.nat_gw[each.key].id
  subnet_id     = aws_subnet.default[each.key].id

  tags = merge({ "Name" = each.key }, var.tags)
}

################################################################################
# Default VPC
################################################################################

resource "aws_default_vpc" "default" {
  #checkov:skip=CKV_AWS_148: "False positive the default VPC is managed by default in the account"
  count = var.manage_default_vpc ? 1 : 0

  tags = merge({ "Name" = "default" }, var.tags)
}

resource "aws_default_security_group" "default_vpc" {
  count = var.manage_default_vpc ? 1 : 0

  vpc_id = aws_default_vpc.default[0].id
}

################################################################################
# Transit Gateway attachment / association / propagation
################################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "default" {
  count = anytrue(var.networks[*].tgw_attachment) ? 1 : 0

  appliance_mode_support                          = var.transit_gateway_appliance_mode_support ? "enable" : "disable"
  subnet_ids                                      = [for subnet in local.vpc_subnets : aws_subnet.default[subnet.key].id if subnet.tgw_attachment]
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.default.id
  tags                                            = { Name = var.name }

  lifecycle {
    ignore_changes = [
      transit_gateway_default_route_table_association, transit_gateway_default_route_table_propagation
    ]
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "default" {
  provider = aws.transit_gateway_account

  count = var.transit_gateway_enable_accepter && anytrue(var.networks[*].tgw_attachment) ? 1 : 0

  transit_gateway_attachment_id                   = aws_ec2_transit_gateway_vpc_attachment.default[count.index].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = var.tags
}

resource "aws_ec2_transit_gateway_route_table_association" "default" {
  provider = aws.transit_gateway_account

  count = anytrue(var.networks[*].tgw_attachment) ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.default[0].id
  transit_gateway_route_table_id = var.transit_gateway_route_table_association

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.default]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "default" {
  provider = aws.transit_gateway_account

  for_each = anytrue(var.networks[*].tgw_attachment) ? var.transit_gateway_route_table_propagation : {}

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.default[0].id
  transit_gateway_route_table_id = each.value

  depends_on = [aws_ec2_transit_gateway_vpc_attachment_accepter.default]
}
