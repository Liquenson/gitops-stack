output "cluster_name" {
  description = "Nombre del clúster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint del clúster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_region" {
  description = "Región del clúster"
  value       = var.region
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}
