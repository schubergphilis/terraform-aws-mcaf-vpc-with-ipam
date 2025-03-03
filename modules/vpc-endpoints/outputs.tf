output "endpoints" {
  description = "A map of the VPC endpoints with their full resource objects and attributes."
  value       = aws_vpc_endpoint.default
}

output "custom_route53_zones" {
  description = "A map of all attributes for each custom DNS zone created, indexed by the endpoint key."
  value = {
    for key, _ in local.custom_zones :
    key => aws_route53_zone.custom_zone[key]
  }
}
