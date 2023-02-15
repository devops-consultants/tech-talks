module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.7.0"

  cluster_name                    = local.eks_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_subnets
  subnet_ids               = module.vpc.private_subnets

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  aws_auth_accounts = [var.aws_account]
  # aws_auth_roles    = concat(local.eks_sso_auth_roles)

  self_managed_node_group_defaults = {
    # create_security_group = false
    instance_type                          = "m6i.large"
    update_launch_template_default_version = true

    iam_role_additional_policies = {
      additional = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    # enable discovery of autoscaling groups by cluster-autoscaler
    autoscaling_group_tags = {
      "k8s.io/cluster-autoscaler/enabled" : true,
      "k8s.io/cluster-autoscaler/${local.eks_name}" : "owned",
    }
  }

  self_managed_node_groups = {

    mixed = {
      name = "mixed"

      max_size     = 5
      desired_size = 1

      pre_bootstrap_user_data = <<-EOT
      export CONTAINER_RUNTIME="containerd"
      export USE_MAX_PODS=false
      EOT

      post_bootstrap_user_data = <<-EOT
      cd /tmp
      sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      sudo systemctl enable amazon-ssm-agent
      sudo systemctl start amazon-ssm-agent
      EOT

      bootstrap_extra_args = "--kubelet-extra-args '--max-pods=110 --node-labels=node.kubernetes.io/lifecycle=spot'"

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 10
          spot_allocation_strategy                 = "price-capacity-optimized"
        }

        # The first instance type in the array is prioritized higher than the last.
        override = [
          {
            instance_type     = "m5a.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m6a.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m6i.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m5.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m5n.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m5zn.large"
            weighted_capacity = "1"
          },
        ]
      }
    }
  }

  tags = local.tags
}

################################################################################
# Cluster Addons
################################################################################

locals {
  aws_vpc_cni_resources = {
    DaemonSet = {
      api_version = "apps/v1"
      name        = "aws-node"
      namespace   = "kube-system"
    },
    ServiceAccount = {
      api_version = "v1"
      name        = "aws-node"
      namespace   = "kube-system"
    },
    ClusterRole = {
      api_version = "rbac.authorization.k8s.io/v1"
      name        = "aws-node"
      namespace   = "kube-system"
    },
    ClusterRoleBinding = {
      api_version = "rbac.authorization.k8s.io/v1"
      name        = "aws-node"
      namespace   = "kube-system"
    },
    CustomResourceDefinition = {
      api_version = "apiextensions.k8s.io/v1"
      name        = "eniconfigs.crd.k8s.amazonaws.com"
      namespace   = "kube-system"
    }
  }
}

resource "kubernetes_labels" "aws_node" {
  for_each      = local.aws_vpc_cni_resources
  api_version   = each.value.api_version
  kind          = each.key
  field_manager = "terraform-label"
  metadata {
    name      = each.value.name
    namespace = each.value.namespace
  }
  labels = {
    "app.kubernetes.io/managed-by" = "Helm"
  }
}

resource "kubernetes_annotations" "aws_node" {
  for_each      = local.aws_vpc_cni_resources
  api_version   = each.value.api_version
  kind          = each.key
  field_manager = "terraform-annotation"
  metadata {
    name      = each.value.name
    namespace = each.value.namespace
  }
  annotations = {
    "meta.helm.sh/release-name"      = "aws-vpc-cni"
    "meta.helm.sh/release-namespace" = "kube-system"
  }
}


resource "helm_release" "aws_cni" {
  name         = "aws-vpc-cni"
  namespace    = "kube-system"
  repository   = "https://aws.github.io/eks-charts"
  chart        = "aws-vpc-cni"
  version      = "1.2.6"
  force_update = true

  depends_on = [
    kubernetes_labels.aws_node,
    kubernetes_annotations.aws_node
  ]

  set {
    name  = "image.account"
    value = "602401143452"
  }

  set {
    name  = "image.region"
    value = "eu-west-1"
  }

  set {
    name  = "env.ENABLE_PREFIX_DELEGATION"
    value = "true"
  }

  set {
    name  = "env.WARM_IP_TARGET"
    value = "5"
  }

  set {
    name  = "env.MINIMUM_IP_TARGET"
    value = "2"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_aws_cni_driver.iam_role_arn
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = module.iam_assumable_role_aws_ebs_csi_driver.iam_role_arn
}

module "iam_assumable_role_aws_ebs_csi_driver" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role                   = true
  role_name                     = "AmazonEKS_EBS_CSI_DriverRole"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

module "iam_assumable_role_aws_cni_driver" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role                   = true
  role_name                     = "AmazonEKSVPCCNIRole"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-node"]
}

# data "aws_ami" "eks_default" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amazon-eks-node-${var.cluster_version}-v*"]
#   }
# }

# resource "tls_private_key" "this" {
#   algorithm = "RSA"
# }

# resource "aws_key_pair" "this" {
#   key_name   = local.name
#   public_key = tls_private_key.this.public_key_openssh
# }

resource "aws_kms_key" "eks" {
  #checkov:skip=CKV_AWS_7:"Ensure rotation for customer created CMKs is enabled"
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}
# resource "aws_kms_key" "ebs" {
#   #checkov:skip=CKV_AWS_7:"Ensure rotation for customer created CMKs is enabled"
#   description             = "Customer managed key to encrypt self managed node group volumes"
#   deletion_window_in_days = 7
#   policy                  = data.aws_iam_policy_document.ebs.json
# }

# This policy is required for the KMS key used for EKS root volumes, so the cluster is allowed to enc/dec/attach encrypted EBS volumes
# data "aws_iam_policy_document" "ebs" {
#   # Copy of default KMS policy that lets you manage it
#   #checkov:skip=CKV_AWS_111:"Ensure IAM policies does not allow write access without constraints"
#   #checkov:skip=CKV_AWS_109:"Ensure IAM policies does not allow permissions management / resource exposure without constraints"
#   statement {
#     sid       = "Enable IAM User Permissions"
#     actions   = ["kms:*"]
#     resources = ["*"]

#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
#     }
#   }

#   # Required for EKS
#   statement {
#     sid = "Allow service-linked role use of the CMK"
#     actions = [
#       "kms:Encrypt",
#       "kms:Decrypt",
#       "kms:ReEncrypt*",
#       "kms:GenerateDataKey*",
#       "kms:DescribeKey"
#     ]
#     resources = ["*"]

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#         # required for the ASG to manage encrypted volumes for nodes
#         module.eks.cluster_iam_role_arn,
#         # required for the cluster / persistentvolume-controller to create encrypted PVCs
#       ]
#     }
#   }

#   statement {
#     sid       = "Allow attachment of persistent resources"
#     actions   = ["kms:CreateGrant"]
#     resources = ["*"]

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#         # required for the ASG to manage encrypted volumes for nodes
#         module.eks.cluster_iam_role_arn,
#         # required for the cluster / persistentvolume-controller to create encrypted PVCs
#       ]
#     }

#     condition {
#       test     = "Bool"
#       variable = "kms:GrantIsForAWSResource"
#       values   = ["true"]
#     }
#   }
# }

resource "aws_security_group_rule" "ingress_nodes_ephemeral" {
  description       = "Node to node ingress on ephemeral ports"
  protocol          = "tcp"
  from_port         = 1025
  to_port           = 65535
  type              = "ingress"
  self              = true
  security_group_id = module.eks.node_security_group_id
}

# fix of kubectl describe apiservice v1beta1.metrics.k8s.io
# Message: failing or missing response from https://<IP>:4443/apis/metrics.k8s.io/v1beta1:
# Get "https://10.0.12.102:4443/apis/metrics.k8s.io/v1beta1": context deadline exceeded
resource "aws_security_group_rule" "metrics_server_ingress" {
  description              = "Cluster API to Nodegroup for metrics server"
  protocol                 = "tcp"
  from_port                = 4443
  to_port                  = 4443
  type                     = "ingress"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "efs_ingress" {
  description       = "Allow EFS traffic from VPC"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  type              = "ingress"
  cidr_blocks       = ["10.0.0.0/8"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_vpc" {
  description       = "Allow all egress to VPCs"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["10.0.0.0/8"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_http" {
  description       = "Egress all HTTP to internet"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_https" {
  description       = "Egress all HTTPS to internet"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "nodes_dns_tcp" {
  description       = "Node to node DNS/TCP"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  type              = "egress"
  self              = true
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "nodes_dns_udp" {
  description       = "Node to node DNS/UDP"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  type              = "egress"
  self              = true
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_dns_tcp" {
  description       = "Egress all DNS/TCP to internet"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_dns_udp" {
  description       = "Egress all DNS/UDP to internet"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_ntp_tcp" {
  description       = "Egress NTP/TCP to internet"
  protocol          = "tcp"
  from_port         = 123
  to_port           = 123
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "egress_ntp_udp" {
  description       = "Egress NTP/UDP to internet"
  protocol          = "udp"
  from_port         = 123
  to_port           = 123
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "webhook_admission_inbound" {
  description              = "webhook_admission_inbound"
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "webhook_admission_outbound" {
  description              = "webhook_admission_outbound"
  type                     = "egress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "loadbalancer_webhook_admission_inbound" {
  description              = "loadbalancer_webhook_admission_inbound"
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "loadbalancer_webhook_admission_outbound" {
  description              = "loadbalancer_webhook_admission_outbound"
  type                     = "egress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}
