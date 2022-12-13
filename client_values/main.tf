terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.24.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.1"
    }
  }

}
# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks_cluster.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_cluster.eks_cluster_id
}

resource "kubernetes_namespace" "monitoring" {

  metadata {

    # annotations = {
    #   name = "annotation-value"
    # }

    # labels = {
    #   mylabel = "label-value"
    # }

    name = "monitoring"
  }
}

# EKS cluster creation
module "eks_cluster" {
  source          = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.13.0"
  cluster_version = "1.23"
  cluster_name    = "infra-tools"
  # vpc_id          = "vpc-095099ed4074eb82e"
  vpc_id          = "vpc-ed1fbb95"

  # Depending on your config, you might need to enable this https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  private_subnet_ids = ["subnet-05d4d4c4e1892a87f","subnet-0cddf53b1f11420f6"]
  managed_node_groups = {
    mg_t3 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["t3.large"]
      desired_size    = 1
      max_size        = 2
      min_size        = 1
      subnet_ids = ["subnet-05d4d4c4e1892a87f","subnet-0cddf53b1f11420f6"]
    }
  }
}

module "eks_blueprints_kubernetes_addons" {

  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.13.0"
  

  eks_cluster_id       = module.eks_cluster.eks_cluster_id
  eks_cluster_endpoint = module.eks_cluster.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_cluster.oidc_provider
  eks_cluster_version  = module.eks_cluster.eks_cluster_version

  # EKS Addons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  #K8s Add-ons
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  enable_metrics_server               = true
  enable_external_dns = true
  eks_cluster_domain = "aws.aurotfp.com"
  external_dns_private_zone = true
  # external_dns_route53_zone_arns = [
  #   "arn:aws:route53::770688751007:hostedzone/Z2C1J0W0DI15CE"
  # ]


  enable_kube_prometheus_stack      = true
  kube_prometheus_stack_helm_config = {
    namespace        = "monitoring"
    version          = "41.6.0"

    values = [
      "${file("prometheus.yaml")}"
    ]
  }
}