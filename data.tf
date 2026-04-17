data "aws_caller_identity" "default" {}

data "aws_region" "default" {}

data "aws_route53profiles_profiles" "default" {
  region = var.region
}
