output "subnet_ids" {
  description = "Map of all networks in the VPC and their subnets"
  value = {
    for network in var.networks : network.name => [
      for availability_zone in var.availability_zones : aws_subnet.default["${network.name}_${availability_zone}"].id
    ]
  }
}

output "route_table_ids" {
  description = "Map of all networks in the VPC and their subnets"
  value = {
    for network in var.networks : network.name => [
      for availability_zone in var.availability_zones : aws_route_table.default["${network.name}_${availability_zone}"].id
    ]
  }
}

output "subnets" {
  description = "Map of all subnets in the VPCs"
  value = {
    for subnet in local.vpc_subnets : subnet.key => merge(subnet, {
      subnet_id      = aws_subnet.default[subnet.key].id
      route_table_id = aws_route_table.default[subnet.key].id
      }
    )
  }
}

output "transit_gateway_attachment_id" {
  description = "Transit Gateway attachment ID"
  value       = anytrue(var.networks[*].tgw_attachment) ? aws_ec2_transit_gateway_vpc_attachment.default[0].id : null
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.public
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.default.id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.default.arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.default.cidr_block
}
