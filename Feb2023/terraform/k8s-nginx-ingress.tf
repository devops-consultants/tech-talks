resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    annotations = {
      name = "ingress-nginx"
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  values = [
    templatefile("${path.module}/templates/nginx-values.yaml", {
      ingress_fqdn = "core-ingress.${data.aws_route53_zone.public.name}"
      vpc_cidr     = module.vpc.vpc_cidr_block
    })
  ]
}
