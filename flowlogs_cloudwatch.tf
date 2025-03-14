resource "aws_flow_log" "default" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  max_aggregation_interval = var.cloudwatch_flow_logs_configuration.max_aggregation_interval
  traffic_type             = var.cloudwatch_flow_logs_configuration.traffic_type
  vpc_id                   = aws_vpc.default.id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  name              = try(var.cloudwatch_flow_logs_configuration.log_group_name, "/ep/${var.name}-flow-logs")
  retention_in_days = var.cloudwatch_flow_logs_configuration.retention_in_days
  kms_key_id        = var.cloudwatch_flow_logs_configuration.kms_key_arn

  tags = var.tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  name_prefix        = var.cloudwatch_flow_logs_configuration.iam_role_name_prefix
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
  path               = var.cloudwatch_flow_logs_configuration.iam_path
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    sid = "VPCFlowLogsAssumeRole"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    effect  = "Allow"
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  role       = aws_iam_role.vpc_flow_logs.name
  policy_arn = aws_iam_policy.vpc_flow_logs.arn
}

resource "aws_iam_policy" "vpc_flow_logs" {
  count = var.cloudwatch_flow_logs_configuration != null ? 1 : 0

  name_prefix = var.cloudwatch_flow_logs_configuration.iam_policy_name_prefix
  path        = var.cloudwatch_flow_logs_configuration.iam_path
  policy      = data.aws_iam_policy_document.vpc_flow_log.json
}

data "aws_iam_policy_document" "vpc_flow_log" {
  statement {
    sid    = "VPCFlowLogsPushToCloudWatch"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:*:*"]
  }
}
