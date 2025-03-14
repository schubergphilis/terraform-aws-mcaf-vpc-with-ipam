locals {
  store_logs_in_s3 = (var.s3_flow_logs_configuration != null)
  create_bucket    = var.s3_flow_logs_configuration != null && try(var.s3_flow_logs_configuration.log_destination == null, false)
}

module "log_bucket" {
  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 1.2.0"
  count   = local.create_bucket ? 1 : 0

  name        = var.s3_flow_logs_configuration.bucket_name
  versioning  = true
  kms_key_arn = var.s3_flow_logs_configuration.kms_key_arn

  tags = var.tags

  lifecycle_rule = [
    {
      id      = "retention"
      enabled = true

      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }

      noncurrent_version_expiration = {
        noncurrent_days = var.s3_flow_logs_configuration.retention_in_days
      }
    }
  ]

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSLogDeliveryWrite",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.s3_flow_logs_configuration.bucket_name}/AWSLogs/${data.aws_caller_identity.default.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "${data.aws_caller_identity.default.account_id}",
                    "s3:x-amz-acl": "bucket-owner-full-control"
                },
                "ArnLike": {
                    "aws:SourceArn": "arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:*"
                }
            }
        },
        {
            "Sid": "AWSLogDeliveryAclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.s3_flow_logs_configuration.bucket_name}",
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "${data.aws_caller_identity.default.account_id}"
                },
                "ArnLike": {
                    "aws:SourceArn": "arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:*"
                }
            }
        }
    ]
}
EOF
}

resource "aws_flow_log" "flow_logs_s3" {
  count = local.store_logs_in_s3 ? 1 : 0

  log_destination      = local.create_bucket ? module.log_bucket[count.index].arn : "arn:aws:s3:::${var.s3_flow_logs_configuration.log_destination}"
  log_destination_type = "s3"
  traffic_type         = var.s3_flow_logs_configuration.traffic_type
  vpc_id               = aws_vpc.default.id
  tags                 = var.tags
  destination_options {
    file_format        = var.s3_flow_logs_configuration.log_format
    per_hour_partition = true
  }
}
