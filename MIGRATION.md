# Migration Guide: Centralizing VPC Endpoints using Route53 Profiles

This guide walks you through the steps to migrate centralized VPC endpoints to use Route53 Profiles, following the approach described in [Streamlining multi-VPC DNS management with Amazon Route 53 Profiles and Interface VPC endpoint integration](https://aws.amazon.com/blogs/networking-and-content-delivery/streamlining-multi-vpc-dns-management-with-amazon-route-53-profiles-and-interface-vpc-endpoint-integration/). Follow the steps in order.

## Prerequisites

- You must be on **v4.0.0** of this module before starting the migration.
- A Route53 Profile must already exist in your hub account, shared with the spoke accounts via AWS RAM, and associated with the relevant VPCs (you will need its ID, e.g. `rp-1a1a1a1a1a1`).

## Step 1: Upgrade to v5.0.0

v5.0.0 introduces a new `route53_profile_id` variable on the `vpc-endpoints` submodule. When provided, all existing custom DNS zones (both ipv4 and dualstack) created by the submodule will be associated with the specified Route53 Profile.

### Update the module version and add `route53_profile_id` to the `vpc-endpoints` submodule

```hcl
module "vpc_endpoints" {
  source  = "schubergphilis/mcaf-vpc-with-ipam/aws//modules/vpc-endpoints"
  version = "~> 5.0.0"
  
  route53_profile_id = "rp-1a1a1a1a1a1a1a"

  # ...existing configuration...
}
```
