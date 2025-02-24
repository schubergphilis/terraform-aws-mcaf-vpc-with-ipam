locals {
  # Produces a map of endpoint keys to an object containing the zone_name & service_region. Each entry represents
  # a custom hosted zone that we want to create. We only include endpoints when either:
  #   1) The endpoint has centralized_endpoint = true (no explicit dns_zone set). In that case,
  #      we derive a zone_name from reversing the service name (e.g., "com.amazonaws.eu-central-1.sts"
  #      becomes "sts.eu-central-1.amazonaws.com").
  #   2) The endpoint explicitly provides private_link_dns_options.dns_zone.
  endpoints_custom_zones = {
    for key, endpoint in var.endpoints :
    key => {
      zone_name = try(endpoint.private_link_dns_options.dns_zone, null) != null ? endpoint.private_link_dns_options.dns_zone : join(
        ".", reverse(split(".", endpoint.service_full_name != null ? endpoint.service_full_name : data.aws_vpc_endpoint_service.default[key].service_name))
      )
      service_region = endpoint.service_region
    } if endpoint.centralized_endpoint == true || try(endpoint.private_link_dns_options.dns_zone != null, false)
  }

  # Produces a list of Route53 record definitions for each endpoint.
  endpoints_custom_records = flatten([
    for key, endpoint in var.endpoints :

    # 1) CENTRALIZED => If `centralized_endpoint = true` AND no custom dns_zone. Create alias apex + wildcard record.
    endpoint.centralized_endpoint == true && length(try(endpoint.private_link_dns_options.dns_records, [])) == 0 ? [
      {
        alias       = true
        endpoint    = key
        record_name = ""
        record_type = "A"
        zone        = key
      },
      {
        alias       = true
        endpoint    = key
        record_name = "*"
        record_type = "A"
        zone        = key
      }
    ]

    # 2) CUSTOM ZONE => If `private_link_dns_options.dns_zone` is set => create one record for each name in `dns_records`
    : length(try(endpoint.private_link_dns_options.dns_records, [])) > 0 ? [
      for record in endpoint.private_link_dns_options.dns_records : {
        alias       = false
        endpoint    = key
        record_name = record
        record_ttl  = endpoint.private_link_dns_options.dns_record_ttl
        record_type = endpoint.private_link_dns_options.dns_record_type
        zone        = endpoint.private_link_dns_options.dns_zone
      }
    ]

    # 3) NEITHER => no records at all
    : []
  ])
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

  auto_accept         = each.value.auto_accept
  ip_address_type     = each.value.ip_address_type
  policy              = each.value.policy
  private_dns_enabled = each.value.centralized_endpoint == true || try(each.value.private_link_dns_options.dns_zone != null, false) ? false : each.value.private_dns_enabled
  route_table_ids     = each.value.route_table_ids
  service_name        = each.value.service_full_name != null ? each.value.service_full_name : data.aws_vpc_endpoint_service.default[each.key].service_name # If user explicitly provides a service endpoint, use it. Otherwise, use the discovered service_name.
  service_region      = each.value.service_region
  tags                = var.tags
  vpc_endpoint_type   = each.value.type
  vpc_id              = var.vpc_id

  # Only set security groups for Interface endpoints.
  # Coalesce var.security_group_ids with the endpoint "override" security_group_ids.
  # Returns a list or null if empty.
  security_group_ids = each.value.type == "Interface" ? (
    length(coalescelist(each.value.security_group_ids, var.security_group_ids)) > 0
    ? coalescelist(each.value.security_group_ids, var.security_group_ids)
    : null
  ) : null

  # Only set subnet IDs for Interface & GatewayLoadBalancer endpoints.
  # Coalesce var.subnet_ids with the endpoint "override" subnet_ids.
  # Returns a list or null if empty.
  subnet_ids = contains(["Interface", "GatewayLoadBalancer"], each.value.type) ? (
    length(coalescelist(each.value.subnet_ids, var.subnet_ids)) > 0
    ? coalescelist(each.value.subnet_ids, var.subnet_ids)
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
# Custom DNS Zone & Records
########################################################################

// the terraform-aws-mcaf-route53-zones is not used due to the lifecycle ignore_changes = [vpc]
resource "aws_route53_zone" "endpoint_custom_zone" {
  #checkov:skip=CKV2_AWS_39: "Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones" - Non centralized vpc endpoint zones are also not logged by AWS.
  #checkov:skip=CKV2_AWS_38: "Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones" - N/A for VPC Endpoints.
  for_each = local.endpoints_custom_zones

  name          = each.value.zone_name
  force_destroy = false
  tags          = var.tags

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

resource "aws_route53_record" "endpoint_dns_records" {
  for_each = { for record in local.endpoints_custom_records : "${record.zone}-${record.record_name}" => record }

  name    = each.value.record_name
  type    = each.value.record_type
  zone_id = aws_route53_zone.endpoint_custom_zone[each.value.endpoint].zone_id

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
