locals {
  create_security_group = var.security_group_name != null || var.security_group_name_prefix != null
  security_group_ids    = local.create_security_group ? concat(var.security_group_ids, [aws_security_group.default[0].id]) : var.security_group_ids

  centralized_endpoints = {
    for key, endpoint in var.endpoints : key => endpoint
    if var.enable_centralized_endpoints && endpoint.type == "Interface"
  }
}

data "aws_region" "current" {}

data "aws_vpc_endpoint_service" "default" {
  for_each = var.endpoints

  service         = each.value.service
  service_regions = each.value.service_region != null ? [each.value.service_region] : []

  filter {
    name   = "service-type"
    values = [each.value.type]
  }
}

################################################################################
# Endpoints
################################################################################

resource "aws_vpc_endpoint" "default" {
  for_each = var.endpoints

  auto_accept         = each.value.auto_accept
  ip_address_type     = each.value.ip_address_type
  policy              = each.value.policy
  private_dns_enabled = var.enable_centralized_endpoints ? false : each.value.private_dns_enabled
  route_table_ids     = each.value.route_table_ids
  service_name        = each.value.service_full_name != null ? each.value.service_full_name : data.aws_vpc_endpoint_service.default[each.key].service_name # If user explicitly provides a service endpoint, use it. Otherwise, use the discovered service_name.
  service_region      = each.value.service_region
  tags                = var.tags
  vpc_endpoint_type   = each.value.type
  vpc_id              = var.vpc_id

  # Only set security groups for Interface endpoints.
  # Merge the local security group IDs (var.security_group_ids + optional module security group) with the endpoint "override" security_group_ids.
  # Returns a distinct set or null if empty.
  security_group_ids = each.value.type == "Interface" ? (
    length(distinct(concat(local.security_group_ids, each.value.security_group_ids))) > 0
    ? distinct(concat(local.security_group_ids, each.value.security_group_ids))
    : null
  ) : null

  # Only set subnet ids for Interface & GatewayLoadBalancer endpoints.
  # Merge var.subnet_ids with the endpoint "override" subnet_ids.
  # Returns a distinct set or null if empty.
  subnet_ids = contains(["Interface", "GatewayLoadBalancer"], each.value.type) ? (
    length(distinct(concat(var.subnet_ids, each.value.subnet_ids))) > 0
    ? distinct(concat(var.subnet_ids, each.value.subnet_ids))
    : null
  ) : null

  dynamic "dns_options" {
    for_each = each.value.dns_options != null ? [each.value.dns_options] : []

    content {
      dns_record_ip_type                             = dns_options.value.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = dns_options.value.private_dns_only_for_inbound_resolver_endpoint
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

########################################################################
# Centralized DNS Zone & Records
########################################################################

resource "aws_route53_zone" "centralized_endpoint_dns_zone" {
  #checkov:skip=CKV2_AWS_39: "Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones" - Non centralized vpc endpoint zones are also not logged by AWS.
  #checkov:skip=CKV2_AWS_38: "Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones" - N/A for VPC Endpoints.
  for_each = local.centralized_endpoints

  force_destroy = false

  // service_name = “com.amazonaws.eu-central-1.sts” to “sts.eu-central-1.amazonaws.com”
  name = join(".", reverse(split(".",
    each.value.service_full_name != null
    ? each.value.service_full_name
    : data.aws_vpc_endpoint_service.default[each.key].service_name
    )
    )
  )

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = each.value.service_region != null ? each.value.service_region : data.aws_region.current.name
  }

  # Prevent the deletion of associated VPCs after the initial creation. 
  # See documentation on aws_route53_zone_association for details.
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "centralized_endpoint_dns_alias" {
  for_each = local.centralized_endpoints

  zone_id = aws_route53_zone.centralized_endpoint_dns_zone[each.key].zone_id
  name    = "" # apex of the zone
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.default[each.key].dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.default[each.key].dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "centralized_endpoint_dns_wildcard" {
  for_each = local.centralized_endpoints

  zone_id = aws_route53_zone.centralized_endpoint_dns_zone[each.key].zone_id
  name    = "*"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.default[each.key].dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.default[each.key].dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "default" {
  #checkov:skip=CKV2_AWS_5: "Ensure that Security Groups are attached to another resource" - False positive.
  count = local.create_security_group ? 1 : 0

  name        = var.security_group_name_prefix == null ? var.security_group_name : null
  name_prefix = var.security_group_name_prefix != null ? var.security_group_name_prefix : null
  description = var.security_group_description
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "default" {
  for_each = local.create_security_group && length(var.security_group_ingress_rules) != 0 ? var.security_group_ingress_rules : {}

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.default[0].id
  to_port                      = each.value.to_port
}
