output "transit_path" {
  description = "Path to the transit secrets engine"
  value       = vault_mount.transit.path
}

output "encryption_key_name" {
  description = "Name of the encryption key for PostgreSQL TDE"
  value       = vault_transit_secret_backend_key.postgres_tde.name
}

output "kubernetes_auth_path" {
  description = "Path to the Kubernetes auth backend"
  value       = vault_auth_backend.kubernetes.path
}

output "postgres_role_name" {
  description = "Kubernetes auth role name for PostgreSQL"
  value       = vault_kubernetes_auth_backend_role.percona_postgres.role_name
}

output "vault_policy_name" {
  description = "Vault policy name for PostgreSQL"
  value       = vault_policy.percona_postgres.name
}
