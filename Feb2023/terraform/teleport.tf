resource "aws_s3_bucket" "teleport_storage" {
  bucket        = local.teleport_bucket_name
  force_destroy = true

  tags = {
    Name = local.teleport_bucket_name
  }
}

resource "aws_s3_bucket_acl" "teleport_storage" {
  bucket = aws_s3_bucket.teleport_storage.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "teleport_storage" {
  bucket = aws_s3_bucket.teleport_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "teleport" {
  name         = "teleport"
  hash_key     = "HashKey"
  range_key    = "FullPath"
  billing_mode = var.dynamodb_billing_mode

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  attribute {
    name = "HashKey"
    type = "S"
  }

  attribute {
    name = "FullPath"
    type = "S"
  }

  stream_enabled   = "true"
  stream_view_type = "NEW_IMAGE"

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }
}

// DynamoDB table for storing cluster events
resource "aws_dynamodb_table" "teleport_events" {
  name         = "teleport-events"
  hash_key     = "SessionID"
  range_key    = "EventIndex"
  billing_mode = var.dynamodb_billing_mode

  server_side_encryption {
    enabled = true
  }

  global_secondary_index {
    name            = "timesearchV2"
    hash_key        = "CreatedAtDate"
    range_key       = "CreatedAt"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  lifecycle {
    ignore_changes = all
  }

  attribute {
    name = "SessionID"
    type = "S"
  }

  attribute {
    name = "EventIndex"
    type = "N"
  }

  attribute {
    name = "CreatedAtDate"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }
}

module "iam_assumable_role_teleport" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.11.2"

  create_role  = true
  role_name    = "teleport"
  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [
    aws_iam_policy.teleport_s3.arn,
    aws_iam_policy.teleport_dynamodb.arn
  ]
  oidc_fully_qualified_subjects = ["system:serviceaccount:teleport:teleport"]
}

resource "kubernetes_namespace" "teleport" {
  metadata {
    name = "teleport"
    annotations = {
      name = "teleport"
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "helm_release" "teleport" {
  name       = "teleport"
  namespace  = kubernetes_namespace.teleport.metadata[0].name
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = "12.0.2"

  values = [
    templatefile("${path.module}/templates/teleport-values.yaml", {
      cluster_fqdn    = "teleport.${data.aws_route53_zone.public.name}"
      region          = var.region
      backend_table   = aws_dynamodb_table.teleport.name
      events_table    = aws_dynamodb_table.teleport_events.name
      sessions_bucket = aws_s3_bucket.teleport_storage.id
      issuer          = local.cluster_issuer_name
      iam_role_arn    = module.iam_assumable_role_teleport.iam_role_arn
    })
  ]
}

# resource "kubernetes_secret" "github_connector" {
#   metadata {
#     name      = "github-connector"
#     namespace = kubernetes_namespace.teleport.metadata[0].name
#   }
#   data = {
#     "github-connector.yaml" = templatefile("${path.module}/templates/github_connector.yaml", {
#       client_id     = var.teleport_client_id
#       client_secret = var.teleport_client_secret
#       # teleport_fqdn = "teleport.${var.environment}.uptimelabs.io"
#       teleport_fqdn = "teleport.uptimelabs.io"
#       organisation  = "uptime-labs"
#     })
#     "token.yaml" = templatefile("${path.module}/templates/teleport_join_token.yaml", {

#     })
#   }
# }

resource "kubernetes_cluster_role" "teleport_impersonation" {
  metadata {
    name = "teleport-impersonation"
  }
  rule {
    api_groups = [""]
    resources = [
      "users",
      "groups",
      "serviceaccounts"
    ]
    verbs = ["impersonate"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectaccessreviews"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "teleport_impersonation" {
  metadata {
    name = "teleport-impersonation"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.teleport_impersonation.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "teleport"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }
}
