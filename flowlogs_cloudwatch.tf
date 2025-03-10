data "aws_iam_policy_document" "log_stream_action" {
  # checkov:skip=CKV_AWS_111: Policy needs to be locked down
  # checkov:skip=CKV_AWS_356: Policy needs to be locked down
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = [
      "*",
    ]
  }
}

module "flow_logs_role" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  source  = "schubergphilis/mcaf-role/aws"
  version = "~> 0.4.0"

  name                  = var.cloudwatch_flow_logs_configuration.iam_role_name
  principal_type        = "Service"
  principal_identifiers = ["vpc-flow-logs.amazonaws.com"]
  role_policy           = data.aws_iam_policy_document.log_stream_action.json
  permissions_boundary  = var.cloudwatch_flow_logs_configuration.iam_role_permission_boundary
  postfix               = var.postfix
  tags                  = var.tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_158: KMS Support needs to be added
  count             = var.cloudwatch_flow_logs_configuration != null ? 1 : 0
  name              = var.cloudwatch_flow_logs_configuration.log_group_name != null ? var.cloudwatch_flow_logs_configuration.log_group_name : "vpc-flow-logs-${var.name}"
  retention_in_days = var.cloudwatch_flow_logs_configuration.retention_in_days
  tags              = var.tags
}

resource "aws_flow_log" "flow_logs" {
  count                = var.cloudwatch_flow_logs_configuration != null ? 1 : 0
  iam_role_arn         = module.flow_logs_role[count.index].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[count.index].arn
  log_destination_type = "cloud-watch-logs"
  log_format           = var.cloudwatch_flow_logs_configuration.log_format
  traffic_type         = var.cloudwatch_flow_logs_configuration.traffic_type
  vpc_id               = aws_vpc.default.id
  tags                 = var.tags
}