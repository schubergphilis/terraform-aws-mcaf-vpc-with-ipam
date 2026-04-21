# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v4.0.0

### Key Changes v4.0.0

### Variables

The `route53_profiles_association` variable has been updated: the `profile_name` attribute has been replaced by `profile_id`. Instead of providing a profile name, you now need to provide the Route53 Profile ID directly to prevent 'known after apply' issues. The variable structure changed from:

```hcl
# Old structure
route53_profiles_association = {
  profile_name     = "profile-name"
  association_name = "association-name"
}

# New structure
route53_profiles_association = {
  profile_id       = "rp-1a1a1a1a1a1a1a"
  association_name = "association-name"
}
```


## Upgrading to v3.0.0

### Key Changes v3.0.0

This module now requires a minimum AWS provider version of 6.0 to support the region parameter. If you are using multiple AWS provider blocks, please read [migrating from multiple provider configurations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support#migrating-from-multiple-provider-configurations).


## Upgrading to v2.0.0

### Variables

The `route53_profiles_association` variable has been simplified to only allow a single Route53 Profile association per VPC (as per AWS limitation). The variable structure changed from:

```hcl
# Old structure
route53_profiles_association = {
  profiles = {
    "profile-name" = {
      association_name = "association-name"
    }
  }
}

# New structure
route53_profiles_association = {
  profile_name     = "profile-name"
  association_name = "association-name"
}
```

Both `profile_name` and `association_name` are now required when the variable is set. To disable the association, simply don't set the variable (it defaults to `null`).

### State Migration

The `aws_route53profiles_association.default` resource changed from using `for_each` to `count`. If you have an existing Route53 Profile association, add a `moved` block to your Terraform configuration to migrate the state:

```hcl
moved {
  from = aws_route53profiles_association.default["<association-name>"]
  to   = aws_route53profiles_association.default[0]
}
```

Replace `<association-name>` with your actual association name (the value you previously set for `association_name`).

For example, if your old configuration was:

```hcl
route53_profiles_association = {
  profiles = {
    "my-profile" = {
      association_name = "my-association"
    }
  }
}
```

Add the following `moved` block:

```hcl
moved {
  from = aws_route53profiles_association.default["my-association"]
  to   = aws_route53profiles_association.default[0]
}
```

## Upgrading to v1.0.0

### Variables

The following variables have been modified:

- `transit_gateway_route_table_propagation` type: list(string) -> map(string).
