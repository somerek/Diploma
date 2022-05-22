provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token
}

data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = aws_eks_cluster.eks_cluster.name
  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}

data "aws_eks_cluster" "eks_cluster" {
  name = var.k8s_name
  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}

resource "kubernetes_namespace" "namespaces" {
  for_each = var.app_env
  metadata {
    name = each.key
  }
}

resource "kubernetes_secret" "secret-backend" {
  for_each = toset(["dev", "prod"])
  metadata {
    name      = "secret-backend"
    namespace = each.key
  }

  data = {
    DB_NAME                 = var.DB_NAME
    DB_PASSWORD             = var.DB_PASSWORD
    DB_USER                 = var.DB_USER
    SERVICE_DB_SERVICE_HOST = "${aws_db_instance.db.address}"
  }

   depends_on = [
    kubernetes_namespace.namespaces
  ]
}

