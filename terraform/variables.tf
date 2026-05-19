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
  default     = "t3.medium"
}

variable "node_count" {
  description = "Número de nodos worker"
  type        = number
  default     = 2
}
