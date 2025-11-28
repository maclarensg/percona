variable "vault_token" {
  description = "Vault root token for authentication"
  type        = string
  sensitive   = true
}

variable "postgres_cluster_name" {
  description = "Name of the PostgreSQL cluster"
  type        = string
  default     = "pg-cluster"
}

variable "postgres_namespace" {
  description = "Kubernetes namespace for PostgreSQL cluster"
  type        = string
  default     = "percona"
}
