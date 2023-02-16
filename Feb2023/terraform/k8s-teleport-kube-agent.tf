resource "helm_release" "teleport_kube_agent" {
  name             = "teleport-agent"
  namespace        = "teleport-agent"
  repository       = "https://charts.releases.teleport.dev"
  chart            = "teleport-kube-agent"
  version          = "12.0.2"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/teleport-kube-agent-values.yaml", {
      teleport_proxy  = "teleport.${data.aws_route53_zone.public.name}:443"
      role_arn        = module.iam_assumable_role_teleport_agent.iam_role_arn
      service_account = "teleport-kube-agent"
      account_id      = data.aws_caller_identity.current.account_id
    })
  ]
}

module "iam_assumable_role_teleport_agent" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.11.2"

  create_role  = true
  role_name    = "teleport-kube-agent"
  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [
    aws_iam_policy.teleport.arn,
    aws_iam_policy.teleport_rds.arn
  ]
  oidc_fully_qualified_subjects = ["system:serviceaccount:teleport-agent:teleport-kube-agent"]
}

resource "aws_iam_policy" "teleport" {
  name        = "teleport-kube-agent"
  path        = "/"
  description = "Teleport Access to AWS Resources"

  policy = data.aws_iam_policy_document.teleport.json
}

data "aws_iam_policy_document" "teleport" {
  statement {
    sid    = "eksDiscovery"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

}

resource "aws_iam_policy" "teleport_rds" {
  name        = "teleport-rds"
  path        = "/"
  description = "Access to RDS resources for Teleport"

  policy = data.aws_iam_policy_document.teleport_rds.json
}

data "aws_iam_policy_document" "teleport_rds" {
  statement {
    sid     = "dbconnect"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    sid    = "describecluster"
    effect = "Allow"
    actions = [
      "rds:DescribeDBClusters",
      "rds:ModifyDBCluster",
      "rds:DescribeDBInstances",
      "rds:ModifyDBInstance"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "iamrolepolicy"
    effect = "Allow"
    actions = [
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/teleport",
      "arn:aws:iam::*:user/username"
    ]
  }
}
