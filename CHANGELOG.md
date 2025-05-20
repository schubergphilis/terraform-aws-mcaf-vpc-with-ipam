# Changelog

All notable changes to this project will automatically be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.1 - 2025-05-20

### What's Changed

#### 🐛 Bug Fixes

* bug: allow deploying the transit gateway and vpc in the same aws account and region (#16) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v1.0.0...v1.0.1

## v1.0.0 - 2025-05-12

### What's Changed

#### 🚀 Features

* breaking: modify transit_gateway_route_table_propagation type to solve known after apply issues (#15) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.5.1...v1.0.0

## v0.5.1 - 2025-03-20

### What's Changed

#### 🐛 Bug Fixes

* fix: Add optionals for s3 flowlogging (#14) @marlonparmentier

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.5.0...v0.5.1

## v0.5.0 - 2025-03-17

### What's Changed

#### 🚀 Features

* feature: add support for S3 flow logging and make CloudWatch flow logging optional (#13) @marlonparmentier

#### 📖 Documentation

* docs: improve examples (#12) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.4.1...v0.5.0

## v0.4.0 - 2025-02-25

### What's Changed

#### 🚀 Features

* feature: add AWS VPC Endpoints submodule & update the minimum required versions to properly support all vpc endpoints settings (#8) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.3.0...v0.4.0

## v0.3.0 - 2025-01-16

### What's Changed

#### 🚀 Features

* feature: allow to specify the iam policy and role path (#7) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.2.0...v0.3.0

## v0.2.0 - 2024-09-04

### What's Changed

#### 🚀 Features

* enhancement: Add TGW Accepter resource (#3) @marlonparmentier

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/v0.1.0...v0.2.0

## v0.1.0 - 2024-07-15

### What's Changed

#### 🚀 Features

* feature: initial code (#1) @marwinbaumannsbp

**Full Changelog**: https://github.com/schubergphilis/terraform-aws-mcaf-vpc-with-ipam/compare/...v0.1.0
