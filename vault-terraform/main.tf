# Enable Transit secrets engine for encryption
resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "Transit engine for Percona PostgreSQL TDE"
}

# Create encryption key for PostgreSQL TDE
resource "vault_transit_secret_backend_key" "postgres_tde" {
  backend = vault_mount.transit.path
  name    = "postgres-tde-key"
  type    = "aes256-gcm96"

  deletion_allowed = true
  exportable       = false
}

# Enable Kubernetes auth method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Configure Kubernetes auth backend
# Note: This uses Vault's ability to auto-discover Kubernetes config
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://kubernetes.default.svc:443"
  disable_local_ca_jwt   = true
}

# Create policy for Percona PostgreSQL to access transit engine
resource "vault_policy" "percona_postgres" {
  name = "percona-postgres-policy"

  policy = <<EOT
# Allow reading and encrypting/decrypting with the transit key
path "transit/encrypt/${vault_transit_secret_backend_key.postgres_tde.name}" {
  capabilities = ["update"]
}

path "transit/decrypt/${vault_transit_secret_backend_key.postgres_tde.name}" {
  capabilities = ["update"]
}

path "transit/keys/${vault_transit_secret_backend_key.postgres_tde.name}" {
  capabilities = ["read"]
}

# Allow reading transit engine configuration
path "transit/keys" {
  capabilities = ["list"]
}
EOT
}

# Create Kubernetes auth role for Percona PostgreSQL
resource "vault_kubernetes_auth_backend_role" "percona_postgres" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "percona-postgres-role"
  bound_service_account_names      = ["percona-postgresql-operator", var.postgres_cluster_name]
  bound_service_account_namespaces = [var.postgres_namespace]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.percona_postgres.name]
}

# Enable KV v2 secrets engine for storing credentials
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 secrets engine for PostgreSQL credentials"
}
