resource "helm_release" "podinfo" {
  name       = "pofinfo"
  namespace  = "default"
  repository = "https://stefanprodan.github.io/podinfo"
  chart      = "podinfo"
  version    = "6.3.3"

  depends_on = [
    module.eks
  ]

  values = [
    templatefile("${path.module}/templates/podinfo-values.yaml", {
      ingress_fqdn = "podinfo.${data.aws_route53_zone.public.name}"
      issuer       = local.cluster_issuer
    })
  ]
}
