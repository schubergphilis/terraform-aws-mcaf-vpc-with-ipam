# AWS VPC Endpoints sub-module

This Terraform module creates and manages VPC Endpoints in AWS. VPC Endpoints allow you to privately connect your VPC to supported AWS services (e.g., S3, DynamoDB, SQS) without requiring an internet gateway, NAT instance, or VPN connection.

The module supports two primary use cases:

1. **Single-VPC Deployment**: Add endpoints directly into a single VPC.
2. [**Centralized (Hub-and-Spoke) Deployment**](https://aws.amazon.com/blogs/networking-and-content-delivery/centralize-access-using-vpc-interface-endpoints/): Provision interface endpoints in a “hub” VPC and expose them to other “spoke” VPCs using VPC peering or an AWS Transit Gateway, enabling private DNS resolution across multiple VPCs. This model can reduce operational overhead and costs by minimizing the number of endpoints.

Both use cases support the AWS Service VPC Endpoints and consuming custom Private Link endpoints.

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

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route53_record.custom_dns_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.custom_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_vpc_endpoint.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc_endpoint_service.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint_service) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC in which the endpoint will be used | `string` | n/a | yes |
| <a name="input_endpoints"></a> [endpoints](#input\_endpoints) | A map of interface and/or gateway endpoints containing their properties and configurations | <pre>map(object({<br/>    auto_accept          = optional(bool)<br/>    ip_address_type      = optional(string)<br/>    policy               = optional(string)<br/>    private_dns_enabled  = optional(bool, true)<br/>    centralized_endpoint = optional(bool, false)<br/>    route_table_ids      = optional(list(string))<br/>    security_group_ids   = optional(list(string), [])<br/>    service              = optional(string) #e.g. s3<br/>    service_full_name    = optional(string) #e.g. com.amazonaws.eu-west-1.s3<br/>    service_region       = optional(string)<br/>    type                 = optional(string, "Interface")<br/>    subnet_ids           = optional(list(string), [])<br/><br/>    dns_options = optional(object({<br/>      dns_record_ip_type                             = optional(string)<br/>      private_dns_only_for_inbound_resolver_endpoint = optional(bool)<br/>    }))<br/><br/>    private_link_dns_options = optional(object({<br/>      dns_record_ttl  = optional(number, 300)<br/>      dns_record_type = optional(string, "CNAME")<br/>      dns_records     = optional(list(string), [])<br/>      dns_zone        = string<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Default security group IDs to associate with all VPC endpoints | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Default subnets IDs to associate with all VPC endpoints | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign on all resources | `map(string)` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Define custom maximum timeout for creating, updating, and deleting VPC endpoint resources | <pre>object({<br/>    create = optional(string, "10m")<br/>    update = optional(string, "10m")<br/>    delete = optional(string, "10m")<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_custom_route53_zones"></a> [custom\_route53\_zones](#output\_custom\_route53\_zones) | A map of all attributes for each custom DNS zone created, indexed by the endpoint key. |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | A map of the VPC endpoints with their full resource objects and attributes. |
<!-- END_TF_DOCS -->
