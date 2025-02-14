output "arn" {
  description = "The Amazon Resource Name (ARN) of the VPC endpoint."
  value       = aws_vpc_endpoint.default.arn
}

output "id" {
  description = "The ID of the VPC endpoint."
  value       = aws_vpc_endpoint.default.id
}

output "network_interface_ids" {
  description = "The list of network interface IDs associated with the VPC endpoint (for Interface endpoints)."
  value       = aws_vpc_endpoint.default.network_interface_ids
}

output "owner_id" {
  description = "The AWS account ID for the VPC endpoint owner."
  value       = aws_vpc_endpoint.default.owner_id
}

output "route53_records" {
  description = "The list of Route53 record names created in the custom zone (if any)."
  value       = local.create_custom_zone ? aws_route53_record.endpoint_dns_records[*].fqdn : []
}

output "route53_zone_id" {
  description = "The Route53 zone ID for the custom endpoint zone (if created)."
  value       = local.create_custom_zone ? aws_route53_zone.endpoint_custom_zone[0].zone_id : null
}

output "route53_zone_name" {
  description = "The domain name of the custom endpoint zone (if created)."
  value       = local.create_custom_zone ? aws_route53_zone.endpoint_custom_zone[0].name : null
}
