resource "aws_iam_policy" "aws_console_sso" {
  name        = "teleport-aws-sso"
  path        = "/"
  description = "Allow Teleport to assume role for AWS Console Access"
  policy      = data.aws_iam_policy_document.aws_console_sso.json
}

data "aws_iam_policy_document" "aws_console_sso" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TeleportPowerUser",
    ]
  }
}

resource "aws_iam_policy" "teleport_s3" {
  name        = "teleport-s3"
  path        = "/"
  description = "Access to AWS S3 resources for Teleport"

  policy = data.aws_iam_policy_document.teleport_s3.json
}

data "aws_iam_policy_document" "teleport_s3" {
  statement {
    sid    = "BucketActions"
    effect = "Allow"
    actions = [
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketVersioning",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketVersioning",
      "s3:CreateBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.teleport_bucket_name}"
    ]
  }

  statement {
    sid    = "ObjectActions"
    effect = "Allow"
    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectRetention",
      "s3:*Object",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      "arn:aws:s3:::${local.teleport_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "teleport_dynamodb" {
  name        = "teleport-dynamodb"
  path        = "/"
  description = "Acces to AWS DynamoDB for Teleport"

  policy = data.aws_iam_policy_document.teleport_dynamodb.json
}

data "aws_iam_policy_document" "teleport_dynamodb" {
  statement {
    sid    = "ClusterStateStorage"
    effect = "Allow"

    actions = [
      "dynamodb:BatchWriteItem",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DescribeStream",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:GetShardIterator",
      "dynamodb:GetItem",
      "dynamodb:UpdateTable",
      "dynamodb:GetRecords",
      "dynamodb:UpdateContinuousBackups"
    ]

    resources = [
      aws_dynamodb_table.teleport.arn,
      "${aws_dynamodb_table.teleport.arn}/stream/*"
    ]
  }

  statement {
    sid    = "ClusterEventsStorage"
    effect = "Allow"

    actions = [
      "dynamodb:CreateTable",
      "dynamodb:BatchWriteItem",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:PutItem",
      "dynamodb:DescribeTable",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateContinuousBackups"
    ]

    resources = [
      aws_dynamodb_table.teleport_events.arn,
      "${aws_dynamodb_table.teleport_events.arn}/index/*"
    ]
  }
}


resource "aws_iam_policy" "teleport_secret" {
  name        = "teleport-secrets"
  path        = "/"
  description = "Access to AWS SecretsManager for Teleport"

  policy = data.aws_iam_policy_document.teleport_secret.json
}

data "aws_iam_policy_document" "teleport_secret" {
  statement {
    sid    = "secretsmanager"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "aws_console_readonly" {
  name               = "TeleportReadOnly"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  tags = {
    Name = "Teleport AWS Console ReadOnly"
  }
}

resource "aws_iam_role" "aws_console_power" {
  name               = "TeleportPowerUser"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  tags = {
    Name = "Teleport AWS Console PowerUser"
  }
}

