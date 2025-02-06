################################################################################
# Endpoints
################################################################################

variable "endpoints" {
  type = map(object({
    auto_accept         = optional(bool)
    ip_address_type     = optional(string)
    policy              = optional(string)
    private_dns_enabled = optional(bool, true)
    route_table_ids     = optional(list(string))
    security_group_ids  = optional(list(string), [])
    service             = optional(string) #e.g. s3
    service_full_name   = optional(string) #e.g. com.amazonaws.eu-west-1.s3
    service_region      = optional(string)
    type                = optional(string, "Interface")
    subnet_ids          = optional(list(string), [])

    dns_options = optional(object({
      dns_record_ip_type                             = optional(string)
      private_dns_only_for_inbound_resolver_endpoint = optional(bool)
    }))
  }))

  default     = {}
  description = "A map of interface and/or gateway endpoints containing their properties and configurations"

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : endpoint.service == null || endpoint.service_full_name == null])
    error_message = "For each endpoint, 'service' and 'service_full_name' cannot both be defined."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : contains(["Gateway", "GatewayLoadBalancer", "Interface", "Resource", "ServiceNetwork"], endpoint.type)])
    error_message = "For each endpoint, 'type' must be one of: Gateway, GatewayLoadBalancer, Interface, Resource, or ServiceNetwork."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : length(coalesce(endpoint.route_table_ids, [])) == 0 || endpoint.type == "Gateway"])
    error_message = "For each endpoint, 'route_table_ids' can only be defined if 'type' is Gateway."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : endpoint.service_region == null || endpoint.type == "Interface"])
    error_message = "For each endpoint, 'service_region' can only be defined if 'type' is Interface."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : endpoint.private_dns_enabled != true || endpoint.type == "Interface"])
    error_message = "For each endpoint, 'private_dns_enabled' can only be true if 'type' is Interface."
  }
}

variable "subnet_ids" {
  description = "Default subnets IDs to associate with all VPC endpoints"
  type        = list(string)
  default     = []
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign on all resources"
}

variable "timeouts" {
  type = object({
    create = optional(string, "10m")
    update = optional(string, "10m")
    delete = optional(string, "10m")
  })

  default     = {}
  description = "Define custom maximum timeout for creating, updating, and deleting VPC endpoint resources"
}

variable "vpc_id" {
  description = "The ID of the VPC in which the endpoint will be used"
  type        = string
  default     = null
}

variable "enable_centralized_endpoints" {
  type        = bool
  default     = false
  description = <<EOT
When enabled, interface endpoints are created with private_dns_enabled = false,
and this module sets up a dedicated private Route 53 hosted zone and A-records.
This facilitates a hub-and-spoke architecture for centralized endpoint access.
EOT
}

################################################################################
# Security Group
################################################################################

variable "security_group_name" {
  type        = string
  default     = null
  description = "Name to use on security group created. Conflicts with `security_group_name_prefix`"
}

variable "security_group_name_prefix" {
  type        = string
  default     = null
  description = "Name prefix to use on security group created. Conflicts with `security_group_name`"
}

variable "security_group_description" {
  type        = string
  default     = null
  description = "Description of the security group created"
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Default security group IDs to associate with all VPC endpoints"
}

variable "security_group_ingress_rules" {
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = string
    from_port                    = optional(number, 0)
    ip_protocol                  = optional(string, "-1")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    to_port                      = optional(number, 0)
  }))
  default     = {}
  description = "Security Group ingress rules"

  validation {
    condition     = alltrue([for o in var.security_group_ingress_rules : (o.cidr_ipv4 != null || o.cidr_ipv6 != null || o.prefix_list_id != null || o.referenced_security_group_id != null)])
    error_message = "Although \"cidr_ipv4\", \"cidr_ipv6\", \"prefix_list_id\", and \"referenced_security_group_id\" are all marked as optional, you must provide one of them in order to configure the ingress of the traffic."
  }
}
