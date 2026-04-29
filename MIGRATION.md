# Migration Guide: Centralizing VPC Endpoints using Route53 Profiles

This guide walks you through the steps to migrate centralized VPC endpoints to use Route53 Profiles, following the approach described in [Streamlining multi-VPC DNS management with Amazon Route 53 Profiles and Interface VPC endpoint integration](https://aws.amazon.com/blogs/networking-and-content-delivery/streamlining-multi-vpc-dns-management-with-amazon-route-53-profiles-and-interface-vpc-endpoint-integration/). Follow the steps in order.

## Prerequisites

- You must be on **v4.0.0** of this module before starting the migration.
- A Route53 Profile must already exist in your hub account, shared with the spoke accounts via AWS RAM, and associated with the relevant VPCs (you will need its ID, e.g. `rp-1a1a1a1a1a`).

## Step 1: Upgrade to v5.1.0

v5.1.0 introduces a new `route53_profile_id` variable on the `vpc-endpoints` submodule. When provided, all existing custom DNS zones (both ipv4 and dualstack) created by the submodule will be associated with the specified Route53 Profile and removes the hub VPC association with custom DNS zones for centralized endpoints. DNS resolution continues functioning because the hub VPC remains associated with the Route 53 Profile, which maintains its connection to the custom DNS zones.

### Update the module version and add `route53_profile_id` to the `vpc-endpoints` submodule

```hcl
module "vpc_endpoints" {
  source  = "schubergphilis/mcaf-vpc-with-ipam/aws//modules/vpc-endpoints"
  version = "~> 5.0.0"
  
  route53_profile_id = "rp-1a1a1a1a1a1a1a"

  # ...existing configuration...
}
```

### 1.1: Disassociate the hub VPC from all custom zones

Since the `aws_route53_zone` resource has `ignore_changes = [vpc]`, Terraform cannot remove the inline VPC association.

> **⚠️ IMPORTANT: You must disassociate the hub VPC manually using the AWS CLI only after upgrading to v5.1.0 and applying the changes.**

Use the following script to list all private hosted zones associated with the hub VPC and disassociate them. The script filters zones by a name pattern to ensure only the relevant endpoint zones are targeted.

```bash
#!/bin/bash
# Usage: ./disassociate_vpc.sh <vpc_id> <vpc_region> <aws_profile>
# Example: ./disassociate_vpc.sh vpc-0abc123def456 eu-central-1 my-aws-profile
#
# This script lists all private hosted zones associated with the hub VPC
# and disassociates only VPC endpoint zones (zones ending in .amazonaws.com. or .api.aws.).

set -euo pipefail

export AWS_PAGER=""

VPC_ID="${1:?Usage: $0 <vpc_id> <vpc_region> <aws_profile>}"
VPC_REGION="${2:?Provide VPC region}"
AWS_PROFILE="${3:?Provide AWS profile name}"

echo "Listing all private hosted zones associated with VPC ${VPC_ID} in ${VPC_REGION}..."

ZONES=$(aws route53 list-hosted-zones-by-vpc \
  --vpc-id "${VPC_ID}" \
  --vpc-region "${VPC_REGION}" \
  --query 'HostedZoneSummaries[*].[HostedZoneId,Name]' \
  --output text \
  --profile "${AWS_PROFILE}")

if [ -z "${ZONES}" ]; then
  echo "No hosted zones found for VPC ${VPC_ID}."
  exit 0
fi

echo "${ZONES}" | while read -r ZONE_ID ZONE_NAME; do
  # Only target VPC endpoint zones (ending in .amazonaws.com. or .api.aws.)
  if ! echo "${ZONE_NAME}" | grep -qE '\.(amazonaws\.com|api\.aws)\.$'; then
    echo "Skipping zone ${ZONE_NAME} (${ZONE_ID}) - not a VPC endpoint zone"
    continue
  fi

  echo "Disassociating VPC ${VPC_ID} from zone ${ZONE_NAME} (${ZONE_ID})..."

  aws route53 disassociate-vpc-from-hosted-zone \
    --hosted-zone-id "${ZONE_ID}" \
    --vpc "VPCRegion=${VPC_REGION},VPCId=${VPC_ID}" \
    --comment "Migration: removing inline VPC association" \
    --profile "${AWS_PROFILE}" \
    && echo "  ✓ Successfully disassociated" \
    || echo "  ✗ Failed (may already be disassociated)"
done

echo "Done."
```

Run the script:

```bash
chmod +x disassociate_vpc.sh
./disassociate_vpc.sh vpc-0abc123def456 eu-central-1 my-aws-profile
```

### 1.2: Verify all VPC endpoint zones have been disassociated

After running the script, verify that no VPC endpoint zones remain associated with the hub VPC:

```bash
aws route53 list-hosted-zones-by-vpc \
  --vpc-id vpc-0abc123def456 \
  --vpc-region eu-central-1 \
  --profile my-aws-profile \
  --query 'HostedZoneSummaries[?ends_with(Name, `.amazonaws.com.`) || ends_with(Name, `.api.aws.`)].[HostedZoneId,Name]' \
  --output table
```

If the output is empty, all VPC endpoint zones have been successfully disassociated. If you still see associations, you can safely re-run the disassociation script it is idempotent and will skip zones that are already disassociated.
