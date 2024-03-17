resource "kubernetes_namespace" "external-dns" {
  metadata {
    name = "external-dns"
    annotations = {
      name = "external-dns"
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "helm_release" "external-dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.38.0"
  namespace  = kubernetes_namespace.external-dns.metadata[0].name
  values = [
    templatefile("${path.module}/templates/external-dns-values.yaml", {
      owner_id     = local.eks_name
      iam_role_arn = module.iam_assumable_role_external_dns.iam_role_arn
    })
  ]

  depends_on = [
    kubernetes_namespace.external-dns
  ]
}

module "iam_assumable_role_external_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.11.2"

  create_role                   = true
  role_name                     = "external-dns"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.external_dns.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:external-dns:externaldns"]
}

resource "aws_iam_policy" "external_dns" {
  name        = "k8s_external_dns"
  path        = "/"
  description = "Access to Route53 for External-DNS"

  policy = data.aws_iam_policy_document.external_dns.json
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    sid    = "UpdateRoute53"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.public.zone_id}",
    ]
  }

  statement {
    sid    = "ListRoute53"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]

    resources = [
      "*",
    ]
  }
}
