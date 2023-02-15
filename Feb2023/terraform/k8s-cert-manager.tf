resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    annotations = {
      name = "cert-manager"
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.11.0"

  set {
    name  = "extraArgs"
    value = "{--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53}"
  }

  values = [
    templatefile("${path.module}/templates/cert-manager-values.yaml", {
      role_arn = module.iam_assumable_role_cert_manager.iam_role_arn
    })
  ]
}


module "iam_assumable_role_cert_manager" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.11.2"

  create_role      = true
  role_name        = "cert-manager"
  provider_url     = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [aws_iam_policy.cert_manager.arn]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${kubernetes_namespace.cert_manager.metadata[0].name}:cert-manager"
  ]
}

resource "aws_iam_policy" "cert_manager" {
  name        = "k8s_cert_manager"
  path        = "/"
  description = "Access to Route53 for Cert-Manager"

  policy = data.aws_iam_policy_document.cert_manager.json
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    sid    = "UpdateRoute53"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.public.zone_id}",
    ]
  }
  statement {
    sid    = "getchange"
    effect = "Allow"
    actions = [
      "route53:GetChange"
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:aws:route53:::change/*"
    ]
  }

  statement {
    sid    = "ListRoute53"
    effect = "Allow"

    actions = [
      "route53:ListHostedZonesByName",
    ]

    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "*",
    ]
  }
}

resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [
    helm_release.cert_manager
  ]

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${local.cluster_issuer_name}
spec:
  acme:
    email: aws+letsencrypt@uptimelabs.io
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: ${local.cluster_issuer_name}
    solvers:
      - selector:
          dnsZones:
            - " ${data.aws_route53_zone.public.name}"
        dns01:
          cnameStrategy: Follow
          route53:
            region: ${var.region}
            hostedZoneId: ${data.aws_route53_zone.public.zone_id}
YAML
}

