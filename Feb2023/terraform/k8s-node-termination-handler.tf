resource "helm_release" "node_termination_handler" {
  name       = "node-termination-handler"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts/"
  chart      = "aws-node-termination-handler"
  version    = "0.21.0"

  depends_on = [
    module.eks
  ]

  set {
    name  = "enableSqsTerminationDraining"
    value = "false"
  }

  set {
    name  = "enableRebalanceMonitoring"
    value = "false"
  }

  set {
    name  = "enableRebalanceDraining"
    value = "false"
  }
}
