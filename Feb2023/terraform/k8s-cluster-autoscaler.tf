resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/templates/cluster-autoscaler-values.yaml", {
      cluster_name         = module.eks.cluster_name
      aws_region           = var.region
      service_account_name = "cluster-autoscaler"
      role_arn             = module.iam_assumable_role_autoscaler.iam_role_arn
    })
  ]
}

module "iam_assumable_role_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.47.1"

  create_role  = true
  role_name    = "cluster-autoscaler"
  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [
    aws_iam_policy.cluster_autoscaler.arn,
  ]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:cluster-autoscaler"]
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "cluster-autoscaler"

  #tfsec:ignore:aws-iam-no-policy-wildcards
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeInstanceTypes",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF

}

