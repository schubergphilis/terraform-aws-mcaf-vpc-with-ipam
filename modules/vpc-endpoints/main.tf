locals {
  ## Endpoints

  # If user explicitly provides a service endpoint, use it. Otherwise, use the discovered service_name.
  real_service_names = {
    for key, endpoint in var.endpoints :
    key => coalesce(endpoint.service_full_name, try(data.aws_vpc_endpoint_service.default[key].service_name, null))
  }

  # Private DNS is disabled for non-Interface endpoint types and when a custom privatelink dns zone is specified.
  # For centralized Interface endpoints (without a custom dns_zone), it is enabled.
  # Otherwise, it uses the value from `private_dns_enabled` for the endpoint.
  private_dns_enabled = {
    for key, endpoint in var.endpoints :
    key => endpoint.type != "Interface" ? false : (
      try(endpoint.private_link_dns_options.dns_zone, null) != null ? false : (
        endpoint.centralized_endpoint ? true : endpoint.private_dns_enabled
      )
    )
  }

  ## Custom DNS Zone & Records

  # Computes the ipv4 DNS zone name for each endpoint, either derived from the service name or explicitly provided.
  # If it's derived from the service name then we reverse the service name
  # (e.g., `com.amazonaws.eu-central-1.sts` becomes `sts.eu-central-1.amazonaws.com`).
  custom_ipv4_zones_names = {
    for key, endpoint in var.endpoints :
    key => try(endpoint.private_link_dns_options.dns_zone, null) != null ? endpoint.private_link_dns_options.dns_zone : join(".", reverse(split(".", local.real_service_names[key])))
  }

  # Computes the dualstack DNS zone for each endpoint, derived from the service name.
  # (e.g., `com.amazonaws.eu-central-1.sts` becomes `sts.eu-central-1.api.aws`).
  custom_dualstack_zones_names = {
    for key, endpoint in var.endpoints :
    key => try(endpoint.private_link_dns_options.dns_zone, null) != null ? null : join(".", concat(
      reverse(slice(split(".", local.real_service_names[key]), 2, length(split(".", local.real_service_names[key])))),
      ["api", "aws"]
    ))
  }

  # A unified map of all custom DNS zones to create, combining both the ipv4 and dualstack zones.
  # A custom DNS zone is created if the endpoint is centralized or if the privatelink `dns_zone` is explicitly provided.
  # Each entry is keyed as "<endpoint_key>" for the ipv4 zone and "<endpoint_key>-dualstack" for the dualstack zone.
  custom_dns_zones = merge(
    {
      for key, endpoint in var.endpoints :
      key => {
        endpoint  = key
        zone_name = local.custom_ipv4_zones_names[key]
      } if endpoint.centralized_endpoint || try(endpoint.private_link_dns_options.dns_zone, null) != null
    },
    {
      for key, endpoint in var.endpoints :
      "${key}-dualstack" => {
        endpoint  = key
        zone_name = local.custom_dualstack_zones_names[key]
      } if endpoint.centralized_endpoint && local.custom_dualstack_zones_names[key] != null
    }
  )

  # Produces a list of Route53 record definitions for each endpoint.
  custom_records = flatten([
    for key, endpoint in var.endpoints :

    # 1) CENTRALIZED => If `centralized_endpoint = true` AND no custom dns_zone. Create alias apex + wildcard record.
    endpoint.centralized_endpoint && try(endpoint.private_link_dns_options.dns_zone, null) == null ? [
      {
        alias       = true
        endpoint    = key
        record_name = ""
        record_type = "A"
      },
      {
        alias       = true
        endpoint    = key
        record_name = "*"
        record_type = "A"
      }
    ]

    # 2) CUSTOM ZONE => If `private_link_dns_options.dns_zone` is set => create one record for each name in `dns_records`
    : try(endpoint.private_link_dns_options.dns_zone, null) != null ? [
      for record in endpoint.private_link_dns_options.dns_records : {
        alias       = false
        endpoint    = key
        record_name = record
        record_ttl  = endpoint.private_link_dns_options.dns_record_ttl
        record_type = endpoint.private_link_dns_options.dns_record_type
      }
    ]

    # 3) NEITHER => no records at all
    : []
  ])

  # A unified map of all custom DNS records to create, combining records for both the ipv4 and dualstack zones.
  # Each record is duplicated for every zone key associated with the same endpoint.
  custom_dns_records = merge([
    for zone_key, zone in local.custom_dns_zones : {
      for record in local.custom_records :
      "${zone_key}-${record.record_name}" => merge(record, { zone_key = zone_key })
      if record.endpoint == zone.endpoint
    }
  ]...)
}

data "aws_region" "current" {}

data "aws_vpc_endpoint_service" "default" {
  # Filter out endpoints that already define service_full_name
  for_each = { for k, v in var.endpoints : k => v if v.service_full_name == null }

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

  region              = var.region
  auto_accept         = each.value.auto_accept
  ip_address_type     = each.value.ip_address_type
  policy              = each.value.policy
  private_dns_enabled = local.private_dns_enabled[each.key]
  route_table_ids     = each.value.route_table_ids
  service_name        = local.real_service_names[each.key]
  service_region      = each.value.service_region
  tags                = var.tags
  vpc_endpoint_type   = each.value.type
  vpc_id              = var.vpc_id

  # Only set security groups for Interface endpoints.
  # Coalesce the provided security group IDs with the default var.security_group_ids (if any).
  # Returns a list of security groups or null if none are provided.
  security_group_ids = each.value.type == "Interface" ? (
    length(coalescelist(each.value.security_group_ids, var.security_group_ids)) > 0
    ? coalescelist(each.value.security_group_ids, var.security_group_ids)
    : null
  ) : null

  # Set subnet IDs only for Interface & GatewayLoadBalancer endpoints.
  # Coalesce the provided subnet IDs with the default var.subnet_ids (if any).
  # Returns a list of subnet IDs or null if none are provided.
  subnet_ids = contains(["Interface", "GatewayLoadBalancer"], each.value.type) ? (
    length(coalescelist(each.value.subnet_ids, var.subnet_ids)) > 0
    ? coalescelist(each.value.subnet_ids, var.subnet_ids)
    : null
  ) : null

  dynamic "dns_options" {
    for_each = each.value.dns_options == null ? [] : [each.value.dns_options]

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
# Custom DNS Zone & Records
########################################################################

# The terraform-aws-mcaf-route53-zones is not used due to the lifecycle ignore_changes = [vpc]
resource "aws_route53_zone" "custom_zone" {
  #checkov:skip=CKV2_AWS_39: "Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones" - Non centralized vpc endpoint zones are also not logged by AWS.
  #checkov:skip=CKV2_AWS_38: "Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones" - N/A for VPC Endpoints.
  for_each = local.custom_dns_zones

  name          = each.value.zone_name
  force_destroy = false
  tags          = var.tags

  # Prevent the deletion of associated VPCs after the initial creation.
  # See documentation on aws_route53_zone_association for details.
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "custom_dns_record" {
  for_each = local.custom_dns_records

  name    = each.value.record_name
  type    = each.value.record_type
  zone_id = aws_route53_zone.custom_zone[each.value.zone_key].zone_id

  # If alias is true, do not set ttl/records; if alias is false, they must be set.
  ttl     = each.value.alias ? null : each.value.record_ttl
  records = each.value.alias ? null : [aws_vpc_endpoint.default[each.value.endpoint].dns_entry[0].dns_name]

  dynamic "alias" {
    for_each = each.value.alias ? { create : true } : {}

    content {
      evaluate_target_health = true
      name                   = aws_vpc_endpoint.default[each.value.endpoint].dns_entry[0].dns_name
      zone_id                = aws_vpc_endpoint.default[each.value.endpoint].dns_entry[0].hosted_zone_id
    }
  }
}

########################################################################
# Route53 profile resource association
########################################################################

resource "aws_route53profiles_resource_association" "custom_zone_association" {
  for_each = local.custom_dns_zones

  region       = var.region
  name         = substr(replace(aws_route53_zone.custom_zone[each.key].name, "/[^a-zA-Z0-9\\-_ ]/", "-"), 0, 64)
  profile_id   = var.route53_profile_id
  resource_arn = aws_route53_zone.custom_zone[each.key].arn
}
