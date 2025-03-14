variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones names or ids in the region."
}

variable "aws_vpc_ipam_pool" {
  type        = string
  description = "ID of the IPAM pool to get CIDRs from."
}

variable "cloudwatch_flow_logs_configuration" {
  type = object({
    iam_path                 = optional(string, "/")
    iam_policy_name_prefix   = optional(string, "vpc-flow-logs-to-cloudwatch-")
    iam_role_name_prefix     = optional(string, "vpc-flow-logs-role-")
    kms_key_arn              = optional(string)
    log_group_name           = optional(string)
    max_aggregation_interval = optional(number, 60)
    retention_in_days        = optional(number, 90)
    traffic_type             = optional(string, "ALL")
  })
  default     = {}
  description = "Cloudwatch flow logs configuration"
}

variable "enable_dns_hostnames" {
  type        = bool
  default     = true
  description = "Enable DNS hostnames in the VPC."
}

variable "manage_default_vpc" {
  type        = bool
  default     = true
  description = "Should be true to adopt and manage the default VPC."
}

variable "name" {
  type        = string
  description = "Name to be used on all the resources as identifier."
}

variable "networks" {
  type = list(object({
    name           = string
    cidr_netmask   = number
    public         = optional(bool, false)
    nat_gw         = optional(bool, false)
    tgw_attachment = optional(bool, false)
    tags           = optional(map(string), {})
  }))
  description = "A list of objects describing requested subnetwork prefixes."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to add to all resources."
}

variable "transit_gateway_appliance_mode_support" {
  type        = bool
  default     = false
  description = "Enable to attach the VPC in appliance mode on the Transit Gateway."
}

variable "transit_gateway_id" {
  type        = string
  default     = ""
  description = "Transit Gateway ID."
}

variable "transit_gateway_route_table_association" {
  type        = string
  default     = ""
  description = "Transit Gateway route table ID to attach the VPC on."
}

variable "transit_gateway_route_table_propagation" {
  type        = list(string)
  default     = []
  description = "Transit Gateway route table ID's to propagate the VPC CIDR to."
}

variable "vpc_cidr_netmask" {
  type        = number
  default     = 20
  description = "The netmask length of the IPv4 CIDR you want to allocate to this VPC."
}
