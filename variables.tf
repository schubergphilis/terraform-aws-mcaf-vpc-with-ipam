variable "availability_zones" {
  type        = list(string)
  description = "A list of availability zones names or ids in the region."
}

variable "aws_vpc_ipam_pool" {
  type        = string
  description = "ID of the IPAM pool to get CIDRs from."
}

# s3_flow_logs_configuration.log_destination accepts full S3 ARNs, optionally including keys. Example:
# "s3://{bucket_name}/{key_name}" will create a folder in the S3 bucket with the {key_name}
variable "s3_flow_logs_configuration" {
  type = object({
    bucket_name              = optional(string)
    kms_key_arn              = string
    log_destination          = optional(string)
    log_format               = optional(string)
    max_aggregation_interval = optional(number, 60)
    retention_in_days        = optional(number, 90)
    traffic_type             = optional(string, "ALL")

    destination_options = optional(object({
      file_format                = optional(string)
      hive_compatible_partitions = optional(bool, false)
      per_hour_partition         = optional(bool, true)
    }), {})
  })
  default     = null
  description = "Variables to enable S3 flow logs for the VPC. Use 'bucket_name' to log to an S3 bucket created by this module. Alternatively, use 'log_destination' to specify a self-managed S3 bucket. The 'log_destination' variable accepts full S3 ARNs, optionally including object keys."

  validation {
    condition     = var.s3_flow_logs_configuration == null || (try(var.s3_flow_logs_configuration.log_destination, null) != null || try(var.s3_flow_logs_configuration.bucket_name, null) != null)
    error_message = "Either log_destination or bucket_name must be specified in s3_flow_logs_configuration if the configuration is provided."
  }
}

variable "cloudwatch_flow_logs_configuration" {
  type = object({
    iam_path                 = optional(string, "/")
    iam_policy_name_prefix   = optional(string, "vpc-flow-logs-to-cloudwatch-")
    iam_role_name_prefix     = optional(string, "vpc-flow-logs-role-")
    kms_key_arn              = string
    log_format               = optional(string)
    log_group_name           = optional(string)
    max_aggregation_interval = optional(number, 60)
    retention_in_days        = optional(number, 90)
    traffic_type             = optional(string, "ALL")
  })
  default     = null
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
  type        = map(string)
  default     = {}
  description = "Map of [logical name]→[Transit Gateway route table ID] to propagate the VPC CIDR to."
}

variable "vpc_cidr_netmask" {
  type        = number
  default     = 20
  description = "The netmask length of the IPv4 CIDR you want to allocate to this VPC."
}
