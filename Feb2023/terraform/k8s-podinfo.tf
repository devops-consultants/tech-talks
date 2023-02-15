resource "helm_release" "podinfo" {
  name       = "pofinfo"
  namespace  = "default"
  repository = "oci://ghcr.io/stefanprodan/charts/podinfo"
  chart      = "podinfo"
  version    = "0.21.0"

  depends_on = [
    module.eks
  ]

  set {
    name  = "redis.enabled"
    value = "true"
  }

  set {
    name  = "replicaCount"
    value = "3"
  }
}
