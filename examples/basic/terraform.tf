terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.82"
      configuration_aliases = [aws.transit_gateway_account]
    }
  }
}
