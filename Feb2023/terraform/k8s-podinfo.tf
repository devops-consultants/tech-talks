resource "helm_release" "podinfo" {
  name       = "podinfo"
  namespace  = "default"
  repository = "https://stefanprodan.github.io/podinfo"
  chart      = "podinfo"
  version    = "6.7.1"

  depends_on = [
    module.eks
  ]

  values = [
    templatefile("${path.module}/templates/podinfo-values.yaml", {
      ingress_fqdn = "podinfo.${data.aws_route53_zone.public.name}"
      issuer       = local.cluster_issuer_name
    })
  ]
}
