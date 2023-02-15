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
  version    = "4.5.2"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  values = [
    templatefile("${path.module}/templates/nginx-values.yaml", {
      ingress_fqdn          = "core-ingress.${data.aws_route53_zone.public.name}"
      internal_ingress_fqdn = "core-ingress.${data.aws_route53_zone.internal.name}"
      vpc_cidr              = data.terraform_remote_state.coreinfra.outputs.vpc_cidr[0]
      environment           = var.environment
    })
  ]
}
