# AWS VPC Endpoints sub-module

This Terraform module creates and manages VPC Endpoints in AWS. VPC Endpoints allow you to privately connect your VPC to supported AWS services (e.g., S3, DynamoDB, SQS) without requiring an internet gateway, NAT instance, or VPN connection.

The module supports two primary use cases:

1. **Single-VPC Deployment**: Add endpoints directly into a single VPC.
2. [**Centralized (Hub-and-Spoke) Deployment**](https://aws.amazon.com/blogs/networking-and-content-delivery/centralize-access-using-vpc-interface-endpoints/): Provision interface endpoints in a “hub” VPC and expose them to other “spoke” VPCs using VPC peering or an AWS Transit Gateway, enabling private DNS resolution across multiple VPCs. This model can reduce operational overhead and costs by minimizing the number of endpoints.


## Usage

See examples directory.

<!-- BEGIN_TF_DOCS -->

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
