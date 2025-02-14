variable "auto_accept" {
  type        = bool
  default     = false
  description = "Whether this endpoint should have auto_accept enabled."
}

variable "centralized_endpoint" {
  type        = bool
  default     = false
  description = <<EOT
When enabled, the interface endpoint is created with private_dns_enabled = false,
and this module sets up a dedicated private Route 53 hosted zone and A-records.
This facilitates a hub-and-spoke architecture for centralized endpoint access.
EOT

  validation {
    condition     = !(var.centralized_endpoint && var.type != "Interface")
    error_message = "'centralized_endpoint' can only be true if 'type' is 'Interface'."
  }
}

variable "dns_options" {
  type = object({
    dns_record_ip_type                             = optional(string)
    private_dns_only_for_inbound_resolver_endpoint = optional(bool)
  })
  default     = {}
  description = "DNS options for this endpoint."
}

variable "ip_address_type" {
  type        = string
  default     = null
  description = "IP address type for the endpoint."

  validation {
    condition     = contains(["ipv4", "ipv6", "dualstack"], var.ip_address_type)
    error_message = "'ip_address_type' must be one of: ipv4, ipv6, or dualstack."
  }
}

variable "policy" {
  type        = string
  default     = null
  description = "Policy JSON to attach to this endpoint."
}

variable "private_dns_enabled" {
  type        = bool
  default     = true
  description = "Whether private DNS is enabled for this endpoint."
}

variable "private_link_dns_options" {
  type = object({
    dns_record_ttl   = optional(number, 300)
    dns_record_type  = optional(string, "CNAME")
    dns_record_names = optional(list(string), [])
    dns_zone         = string
  })
  default     = {}
  description = "Custom DNS options for PrivateLink endpoints."
}

variable "route_table_ids" {
  type        = list(string)
  default     = []
  description = "List of route table IDs to associate."

  validation {
    condition     = length(var.route_table_ids) == 0 || var.type == "Gateway"
    error_message = "'route_table_ids' can only be set if 'type' is 'Gateway'."
  }
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security group IDs to associate with this endpoint. Only applies to Interface endpoints."
}

variable "service" {
  type        = string
  default     = null
  description = "Short service name (e.g. 's3'), mutually exclusive with 'service_full_name'."

  validation {
    condition     = var.service == null || var.service_full_name == null
    error_message = "'service' and 'service_full_name' cannot both be defined."
  }
}

variable "service_full_name" {
  type        = string
  default     = null
  description = "Full service name (e.g., 'com.amazonaws.eu-west-1.s3'), mutually exclusive with 'service'."
}

variable "service_region" {
  type        = string
  default     = null
  description = "Service region override. Only applies to Interface endpoints."

  validation {
    condition     = var.service_region == null || var.type == "Interface"
    error_message = "'service_region' can only be defined if 'type' is 'Interface'."
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnet IDs to associate with this endpoint. Only applies to Interface & GatewayLoadBalancer endpoints."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign on all resources."
}

variable "timeouts" {
  type = object({
    create = optional(string, "10m")
    update = optional(string, "10m")
    delete = optional(string, "10m")
  })
  default     = {}
  description = "Define custom maximum timeout for creating, updating, and deleting the VPC endpoint."
}

variable "type" {
  type        = string
  default     = "Interface"
  description = "Endpoint type: must be one of Gateway, GatewayLoadBalancer, Interface, Resource, or ServiceNetwork."

  validation {
    condition = contains(
      ["Gateway", "GatewayLoadBalancer", "Interface", "Resource", "ServiceNetwork"],
      var.type
    )
    error_message = "'type' must be one of: Gateway, GatewayLoadBalancer, Interface, Resource, or ServiceNetwork."
  }
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the endpoint will be used."
}
