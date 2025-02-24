################################################################################
# Endpoints
################################################################################

variable "endpoints" {
  type = map(object({
    auto_accept          = optional(bool)
    ip_address_type      = optional(string)
    policy               = optional(string)
    private_dns_enabled  = optional(bool, true)
    centralized_endpoint = optional(bool, false)
    route_table_ids      = optional(list(string))
    security_group_ids   = optional(list(string), [])
    service              = optional(string) #e.g. s3
    service_full_name    = optional(string) #e.g. com.amazonaws.eu-west-1.s3
    service_region       = optional(string)
    type                 = optional(string, "Interface")
    subnet_ids           = optional(list(string), [])

    dns_options = optional(object({
      dns_record_ip_type                             = optional(string)
      private_dns_only_for_inbound_resolver_endpoint = optional(bool)
    }))

    private_link_dns_options = optional(object({
      dns_record_ttl  = optional(number, 300)
      dns_record_type = optional(string, "CNAME")
      dns_records     = optional(list(string), [])
      dns_zone        = string
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
    condition     = alltrue([for endpoint in values(var.endpoints) : endpoint.centralized_endpoint != true || endpoint.type == "Interface"])
    error_message = "For each endpoint, 'centralized_endpoint' can only be true if 'type' is Interface."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.endpoints) : endpoint.service_region == null || endpoint.type == "Interface"])
    error_message = "For each endpoint, 'service_region' can only be defined if 'type' is Interface."
  }
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Default security group IDs to associate with all VPC endpoints"
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Default subnets IDs to associate with all VPC endpoints"
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
  type        = string
  description = "The ID of the VPC in which the endpoint will be used"
}
