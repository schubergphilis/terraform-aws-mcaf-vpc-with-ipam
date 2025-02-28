output "endpoints" {
  description = "A map of the VPC endpoints with their full resource objects and attributes."
  value       = aws_vpc_endpoint.default
}

output "custom_route53_zones" {
  description = "A map of zone_id and zone_name for each custom DNS zone created, indexed by the endpoint key."
  value = {
    for key, _ in local.custom_zones :
    key => {
      zone_id   = aws_route53_zone.custom_zone[key].zone_id
      zone_name = aws_route53_zone.custom_zone[key].name
    }
  }
}
