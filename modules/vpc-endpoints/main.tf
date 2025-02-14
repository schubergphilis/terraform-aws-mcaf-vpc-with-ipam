locals {
  ## Endpoints

  # Real service name is either the user-specified "service_full_name" or discovered from data source.
  real_service_name = var.service_full_name != null ? var.service_full_name : data.aws_vpc_endpoint_service.default[0].service_name

  # Set private DNS to false if centralized endpoint is enabled, a DNS zone is provided, or type is not "Interface"
  private_dns_enabled = (var.centralized_endpoint || try(var.private_link_dns_options.dns_zone != null, false) || var.type != "Interface") ? false : var.private_dns_enabled

  ## Custom DNS Zone & Records

  # Create a zone if `centralized_endpoint = true` or when an `dns_zone` is provided.
  create_custom_zone = var.centralized_endpoint || try(var.private_link_dns_options.dns_zone, null) != null

  # Calculate the zone name
  #   1) If no explicit dns_zone is set, derive a zone_name from reversing the real service name 
  #      (e.g., "com.amazonaws.eu-central-1.sts" becomes "sts.eu-central-1.amazonaws.com").
  #   2) The endpoint explicitly provides private_link_dns_options.dns_zone.
  zone_name = try(var.private_link_dns_options.dns_zone, null) != null ? var.private_link_dns_options.dns_zone : join(".", reverse(split(".", local.real_service_name)))

  # Calculate the list of Route53 record definitions'
  custom_records = (
    # 1) CENTRALIZED => If `centralized_endpoint = true` AND no custom dns_zone. Create alias apex + wildcard record.
    var.centralized_endpoint && try(var.private_link_dns_options.dns_zone, null) == null) ? ([
      {
        alias       = true
        record_name = ""
        record_type = "A"
      },
      {
        alias       = true
        record_name = "*"
        record_type = "A"
      }
      # 2) CUSTOM ZONE => If `private_link_dns_options.dns_zone` is set => create one record for each name in `dns_records`
    ]) : try(var.private_link_dns_options.dns_zone, null) != null ? [
    for record in var.private_link_dns_options.dns_record_names : {
      alias       = false
      record_name = record
      record_ttl  = var.private_link_dns_options.dns_record_ttl
      record_type = var.private_link_dns_options.dns_record_type
    }
    # 3) NEITHER => no records at all
  ] : []
}

data "aws_region" "current" {}

data "aws_vpc_endpoint_service" "default" {
  # Filter out endpoints that already define service_full_name
  count = var.service_full_name == null ? 1 : 0

  service         = var.service
  service_regions = var.service_region != null ? [var.service_region] : []

  filter {
    name   = "service-type"
    values = [var.type]
  }
}

################################################################################
# Endpoints
################################################################################

resource "aws_vpc_endpoint" "default" {
  auto_accept         = var.auto_accept
  ip_address_type     = var.ip_address_type
  policy              = var.policy
  private_dns_enabled = local.private_dns_enabled
  route_table_ids     = var.route_table_ids
  security_group_ids  = var.type == "Interface" ? var.security_group_ids : []
  service_name        = local.real_service_name
  service_region      = var.service_region
  subnet_ids          = contains(["Interface", "GatewayLoadBalancer"], var.type) ? var.subnet_ids : null
  tags                = var.tags
  vpc_endpoint_type   = var.type
  vpc_id              = var.vpc_id

  dynamic "dns_options" {
    for_each = var.dns_options == null ? [] : [var.dns_options]

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
  count = local.create_custom_zone ? 1 : 0

  name          = local.zone_name
  force_destroy = false
  tags          = var.tags

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = var.service_region != null ? var.service_region : data.aws_region.current.name
  }

  # Prevent the deletion of associated VPCs after the initial creation. 
  # See documentation on aws_route53_zone_association for details.
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "endpoint_dns_records" {
  for_each = local.create_custom_zone ? { for record in local.custom_records : record.record_name => record } : {}

  name    = each.value.record_name
  type    = each.value.record_type
  zone_id = aws_route53_zone.endpoint_custom_zone[0].zone_id

  # If alias is true, do not set ttl/records; if alias is false, they must be set.
  ttl     = each.value.alias ? null : each.value.record_ttl
  records = each.value.alias ? null : [aws_vpc_endpoint.default.dns_entry[0].dns_name]

  dynamic "alias" {
    for_each = each.value.alias ? { create : true } : {}

    content {
      evaluate_target_health = true
      name                   = aws_vpc_endpoint.default.dns_entry[0].dns_name
      zone_id                = aws_vpc_endpoint.default.dns_entry[0].hosted_zone_id
    }
  }
}
