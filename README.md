# terraform-aws-mcaf-vpc-with-ipam

Terraform module to:

- create and manage a VPC (using a CIDR provided by an existing IPAM pool)
- (optionally) attach the VPC to an existing transit gateway
- (optionally) create VPC endpoint resources using the [VPC endpoints](modules/vpc-endpoints) submodule

This module will be merged with the [terraform-aws-mcaf-vpc](https://github.com/schubergphilis/terraform-aws-mcaf-vpc) module in the future.

## Usage

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.82 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.82 |
| <a name="provider_aws.transit_gateway_account"></a> [aws.transit\_gateway\_account](#provider\_aws.transit\_gateway\_account) | >= 5.82 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_flow_logs_role"></a> [flow\_logs\_role](#module\_flow\_logs\_role) | schubergphilis/mcaf-role/aws | ~> 0.4.0 |
| <a name="module_log_bucket"></a> [log\_bucket](#module\_log\_bucket) | schubergphilis/mcaf-s3/aws | ~> 1.2.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.default_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_default_security_group.workload_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_default_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_vpc) | resource |
| [aws_ec2_transit_gateway_route_table_association.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_ec2_transit_gateway_vpc_attachment_accepter.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment_accepter) | resource |
| [aws_eip.nat_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_flow_log.flow_logs_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_internet_gateway.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipam_preview_next_cidr.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_preview_next_cidr) | resource |
| [aws_caller_identity.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.log_stream_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | A list of availability zones names or ids in the region. | `list(string)` | n/a | yes |
| <a name="input_aws_vpc_ipam_pool"></a> [aws\_vpc\_ipam\_pool](#input\_aws\_vpc\_ipam\_pool) | ID of the IPAM pool to get CIDRs from. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name to be used on all the resources as identifier. | `string` | n/a | yes |
| <a name="input_networks"></a> [networks](#input\_networks) | A list of objects describing requested subnetwork prefixes. | <pre>list(object({<br/>    name           = string<br/>    cidr_netmask   = number<br/>    public         = optional(bool, false)<br/>    nat_gw         = optional(bool, false)<br/>    tgw_attachment = optional(bool, false)<br/>    tags           = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_cloudwatch_flow_logs_configuration"></a> [cloudwatch\_flow\_logs\_configuration](#input\_cloudwatch\_flow\_logs\_configuration) | Variables to enable CloudWatch flow logs for the VPC. | <pre>object({<br/>    iam_role_name                = string<br/>    iam_role_permission_boundary = optional(string, null)<br/>    log_format                   = optional(string, null)<br/>    log_group_name               = string<br/>    retention_in_days            = number<br/>    traffic_type                 = string<br/>  })</pre> | `null` | no |
| <a name="input_enable_dns_hostnames"></a> [enable\_dns\_hostnames](#input\_enable\_dns\_hostnames) | Enable DNS hostnames in the VPC. | `bool` | `true` | no |
| <a name="input_manage_default_vpc"></a> [manage\_default\_vpc](#input\_manage\_default\_vpc) | Should be true to adopt and manage the default VPC. | `bool` | `true` | no |
| <a name="input_postfix"></a> [postfix](#input\_postfix) | Postfix the role and policy names with Role and Policy | `bool` | `false` | no |
| <a name="input_s3_flow_logs_configuration"></a> [s3\_flow\_logs\_configuration](#input\_s3\_flow\_logs\_configuration) | Variables to enable S3 flow logs for the VPC. | <pre>object({<br/>    bucket_name       = optional(string, null)<br/>    log_destination   = optional(string, null)<br/>    log_format        = optional(string, null)<br/>    kms_key_arn       = optional(string, null)<br/>    retention_in_days = number<br/>    traffic_type      = string<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_appliance_mode_support"></a> [transit\_gateway\_appliance\_mode\_support](#input\_transit\_gateway\_appliance\_mode\_support) | Enable to attach the VPC in appliance mode on the Transit Gateway. | `bool` | `false` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway ID. | `string` | `""` | no |
| <a name="input_transit_gateway_route_table_association"></a> [transit\_gateway\_route\_table\_association](#input\_transit\_gateway\_route\_table\_association) | Transit Gateway route table ID to attach the VPC on. | `string` | `""` | no |
| <a name="input_transit_gateway_route_table_propagation"></a> [transit\_gateway\_route\_table\_propagation](#input\_transit\_gateway\_route\_table\_propagation) | Transit Gateway route table ID's to propagate the VPC CIDR to. | `list(string)` | `[]` | no |
| <a name="input_vpc_cidr_netmask"></a> [vpc\_cidr\_netmask](#input\_vpc\_cidr\_netmask) | The netmask length of the IPv4 CIDR you want to allocate to this VPC. | `number` | `20` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of NAT Gateway IDs |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Map of all networks in the VPC and their subnets |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Map of all networks in the VPC and their subnets |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of all subnets in the VPCs |
| <a name="output_transit_gateway_attachment_id"></a> [transit\_gateway\_attachment\_id](#output\_transit\_gateway\_attachment\_id) | Transit Gateway attachment ID |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | The ARN of the VPC |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END_TF_DOCS -->

## License

**Copyright:** Schuberg Philis

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
