variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
  default     = "gitops-stack-prod"
}

variable "cluster_version" {
  description = "Versión de Kubernetes"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "Tipo de instancia para los nodos"
  type        = string
  default     = "t3.small"
}

variable "node_count" {
  description = "Número de nodos worker"
  type        = number
  default     = 2
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "538079272432"
}

variable "eks_admin_user" {
  description = "Usuario IAM con acceso admin al cluster EKS"
  type        = string
  default     = "liquenson-cli"
}
