terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
  backend "s3" {
    bucket  = "tf-state-bucket-epam-diploma2"
    encrypt = true
    key     = "terraform.tfstate"
  }
  required_version = "~> 1.0"
}

provider "aws" {
  region = var.default_aws_region
}



data "aws_availability_zones" "working" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  enable_classiclink   = "false"
  instance_tenancy     = "default"

  tags = merge(var.common_tags, { Name = "VPC ${var.vpc_cidr_block}" })
}

# ---------------------------------------------------------------------------------------------------------------------
# PUBLIC AND PRIVATE SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "subnet-public-a" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.working.names[0]
  cidr_block              = var.public_subnet_a_cidr_block
  map_public_ip_on_launch = "true"

  tags = merge(var.common_tags, { Name = "Public subnet A in ${data.aws_availability_zones.working.names[0]}" })
}

resource "aws_subnet" "subnet-public-b" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.working.names[1]
  cidr_block              = var.public_subnet_b_cidr_block
  map_public_ip_on_launch = "true"

  tags = merge(var.common_tags, { Name = "Public subnet B in ${data.aws_availability_zones.working.names[0]}" })
}

resource "aws_subnet" "subnet-private-a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.working.names[0]
  cidr_block        = var.private_subnet_a_cidr_block

  tags = merge(var.common_tags, { Name = "Private subnet A in ${data.aws_availability_zones.working.names[0]}" })
}

resource "aws_subnet" "subnet-private-b" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.working.names[1]
  cidr_block        = var.private_subnet_b_cidr_block

  tags = merge(var.common_tags, { Name = "Private subnet B in ${data.aws_availability_zones.working.names[0]}" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.common_tags, { Name = "Internet  GateWay" })
}

# ---------------------------------------------------------------------------------------------------------------------
# ROUTE TABLE FOR SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route_table" "public-crt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, { Name = "Public route table" })
}

resource "aws_route_table" "private-crt" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.common_tags, { Name = "Private route table" })
}

resource "aws_route_table_association" "crta-public-subnet-a" {
  subnet_id      = aws_subnet.subnet-public-a.id
  route_table_id = aws_route_table.public-crt.id
}

resource "aws_route_table_association" "crta-public-subnet-b" {
  subnet_id      = aws_subnet.subnet-public-b.id
  route_table_id = aws_route_table.public-crt.id
}

resource "aws_route_table_association" "crta-private-subnet-a" {
  subnet_id      = aws_subnet.subnet-private-a.id
  route_table_id = aws_route_table.private-crt.id
}

resource "aws_route_table_association" "crta-private-subnet-b" {
  subnet_id      = aws_subnet.subnet-private-b.id
  route_table_id = aws_route_table.private-crt.id
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUPS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "allow_ssh_sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "ssh_by_ip"
  description = "Allow ssh by IP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allow_ssh_from_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "Allow connection from IP" })
}

# FOR DATABASE

resource "aws_security_group" "db_instance" {
  name   = "Database SG"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "allow_db_access" {
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  security_group_id = aws_security_group.db_instance.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "db_subnet"
  subnet_ids = [aws_subnet.subnet-private-a.id, aws_subnet.subnet-private-b.id]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEVE DATABASE INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "db" {
  identifier             = "db"
  allocated_storage      = var.allocated_storage
  engine                 = var.engine_name
  engine_version         = var.engine_version
  port                   = var.port
  name                   = var.DB_NAME
  username               = var.DB_USER
  password               = var.DB_PASSWORD
  instance_class         = var.instance_class
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.id
  vpc_security_group_ids = [aws_security_group.db_instance.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true

  tags = merge(var.common_tags, { Name = "RDS database" })
}


# ---------------------------------------------------------------------------------------------------------------------
# ELASTIC KUBERNETES SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "iam-role-eks-cluster" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam-role-eks-cluster.name
}


resource "aws_security_group" "eks-cluster" {
  name   = "eks-cluster-SG"
  vpc_id = aws_vpc.vpc.id


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.k8s_name
  role_arn = aws_iam_role.iam-role-eks-cluster.arn
  version  = var.k8s_version

  vpc_config {
    security_group_ids = [aws_security_group.eks-cluster.id, aws_security_group.db_instance.id]
    subnet_ids         = [aws_subnet.subnet-private-a.id, aws_subnet.subnet-private-b.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy]
}

resource "aws_iam_role" "eks_nodes" {
  name = "eks-node-group"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "k8s_node_group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  instance_types  = [var.k8s_node_type]
  subnet_ids      = [aws_subnet.subnet-public-a.id, aws_subnet.subnet-public-b.id]

  tags = merge(var.common_tags, { Name = "Node k8s" })

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}


data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURATION K8S
# ---------------------------------------------------------------------------------------------------------------------

provider "kubectl" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  #   https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.name]
    command     = "aws"
  }
  load_config_file = false
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.name]
      command     = "aws"
    }
  }
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = "eks_cluster"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURATION Arogo CD
# ---------------------------------------------------------------------------------------------------------------------


data "http" "argocd" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}
data "kubectl_file_documents" "argocd" {
  content = data.http.argocd.body
}

resource "kubernetes_namespace" "namespace-argocd" {
  metadata {
    name = "argocd"
  }
  # depends_on = [
  #   helm_release.elk,
  #   helm_release.elk-elasticsearch
  # ]
}

resource "kubectl_manifest" "argocd" {
  depends_on = [
    kubernetes_namespace.namespace-argocd
  ]
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)
  override_namespace = "argocd"
}

resource "null_resource" "argocd-no-tls" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.default_aws_region} --name k8s && kubectl patch deployment -n argocd argocd-server --patch-file ./manifests/argocd/argo-no-tls.yaml"
  }
  depends_on = [
    kubectl_manifest.argocd
  ]
}

data "external" "argocd_pass" {
  program = ["bash", "scripts/argocd_pass.sh"]
  depends_on = [
    null_resource.argocd-no-tls
  ]
}

resource "kubernetes_ingress" "ingress-argocd" {
  depends_on = [
    kubernetes_namespace.namespace-argocd
  ]
  metadata {
    name      = "ingress-argocd"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"                    = "nginx"
      "alb.ingress.kubernetes.io/ssl-passthrough"      = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
      "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"

    }
  }
  spec {
    rule {
      host = "argocd.${var.domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "argocd-server"
            service_port = 80
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Deploy App
# ---------------------------------------------------------------------------------------------------------------------

data "kubectl_file_documents" "music-page-app" {
  content = file("manifests/argocd/music-page-app.yaml")
}

resource "kubectl_manifest" "music-page-app" {
  depends_on = [
    kubectl_manifest.argocd,
  ]
  count     = length(data.kubectl_file_documents.music-page-app.documents)
  yaml_body = element(data.kubectl_file_documents.music-page-app.documents, count.index)
  # yaml_body = data.kubectl_path_documents.manifests[each.key].documents.value
  override_namespace = "argocd"
}

# ---------------------------------------------------------------------------------------------------------------------
# Nginx ingress controller
# ---------------------------------------------------------------------------------------------------------------------


resource "helm_release" "ingress-nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  chart            = "ingress-nginx"
  version          = "4.1.0"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }
  set {
    name  = "controller.ingressClassResource.enabled"
    value = "true"
  }
  set {
    name  = "controller.ingressClassByName"
    value = "true"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Route53
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "route53" {
  zone_id = var.zone_id
  name    = "*.${var.domain}"
  type    = "CNAME"
  ttl     = "1"
  records = [data.kubernetes_service.ingress-nginx.status[0].load_balancer[0].ingress[0].hostname]
}

# ---------------------------------------------------------------------------------------------------------------------
# ELK
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "elk" {
  for_each         = toset(["kibana", "filebeat"])
  name             = "elk-${each.key}"
  repository       = "https://helm.elastic.co"
  chart            = each.key
  values           = ["${file("manifests/elk/values-${each.key}.yaml")}"]
  namespace        = "elk"
  create_namespace = true
}

resource "helm_release" "elk-elasticsearch" {
  name             = "elk-elasticsearch"
  repository       = "https://helm.elastic.co"
  chart            = "elasticsearch"
  values           = ["${file("manifests/elk/values-elasticsearch.yaml")}"]
  namespace        = "elk"
  create_namespace = true
  set {
    name  = "ingress.enabled"
    value = "true"
  }
}

resource "kubernetes_ingress" "ingress-kibana" {
  depends_on = [
    helm_release.elk
  ]
  wait_for_load_balancer = true
  metadata {
    name      = "ingress-kibana"
    namespace = "elk"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      host = "kibana.${var.domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "elk-kibana-kibana"
            service_port = 5601
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "monitoring" {
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  name             = "kube-prometheus-stack"
  create_namespace = true
  namespace        = "monitoring"
  version          = "33.0.0"
  # values           = ["${file("values-grafana.yaml")}"]
}

resource "kubernetes_ingress" "ingress-grafana" {
  depends_on = [
    helm_release.monitoring
  ]

  wait_for_load_balancer = true
  metadata {
    name      = "ingress-grafana"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      host = "grafana.${var.domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "kube-prometheus-stack-grafana"
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "ingress-prometheus" {
  depends_on = [
    helm_release.monitoring
  ]

  wait_for_load_balancer = true
  metadata {
    name      = "ingress-prometheus"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      host = "prometheus.${var.domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "kube-prometheus-stack-prometheus"
            service_port = 9090
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Metrics server
# ---------------------------------------------------------------------------------------------------------------------

data "http" "metrics-server" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

data "kubectl_file_documents" "metrics-server" {
  content = data.http.metrics-server.body
}

resource "kubectl_manifest" "metrics-server" {
  # depends_on = [
  #   helm_release.elk,
  #   helm_release.elk-elasticsearch
  # ]
  count     = length(data.kubectl_file_documents.metrics-server.documents)
  yaml_body = element(data.kubectl_file_documents.metrics-server.documents, count.index)
}

data "kubernetes_service" "ingress-nginx" {
  depends_on = [
    kubectl_manifest.music-page-app
  ]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.ingress-nginx.metadata[0].namespace
  }
}

