output "data_aws_caller_identity" {
  value = data.aws_caller_identity.current.account_id
}

output "data_aws_region_name" {
  value = data.aws_region.current.name
}

output "data_aws_region_description" {
  value = data.aws_region.current.description
}

# ---------------------------------------------------------------------------------------------------------------------
# DATABASE INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

output "dev_rds_replica_connection_parameters" {
  description = "DEV RDS replica instance connection parameters"
  value       = "-h ${aws_db_instance.db.address} -p ${aws_db_instance.db.port} -U ${aws_db_instance.db.username} ${var.DB_NAME}"
}

# ---------------------------------------------------------------------------------------------------------------------
# ELASTIC KUBERNETES SERVICE
# ---------------------------------------------------------------------------------------------------------------------

output "cluster_id" {
  description = "EKS cluster ID."
  value       = data.aws_eks_cluster.cluster.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = data.aws_eks_cluster.cluster.endpoint
}

output "load-balancer-hostname" {
  value = data.kubernetes_service.ingress-nginx.status[0].load_balancer[0].ingress[0].hostname
}

output "argocd-pass" {
  description = "ArgoCD admin password"
  value       = data.external.argocd_pass.result.pass
}
