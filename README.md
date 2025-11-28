# Percona PostgreSQL with TDE (Transparent Data Encryption)

## Overview
This repository contains the complete setup for Percona PostgreSQL with Transparent Data Encryption (TDE) using HashiCorp Vault as the key management provider.

## Components
- **HashiCorp Vault v0.31.0**: Secrets management and key provider
- **Percona PostgreSQL Operator v2.8.0**: Kubernetes operator for PostgreSQL
- **PostgreSQL 17.6-1**: Percona Distribution with pg_tde extension v2.0

## Quick Start

### Complete Automated Setup
```bash
# Setup everything (Vault + Percona + TDE)
task all:setup
```

### Individual Components

#### 1. Vault Setup
```bash
# Install and configure Vault
task vault:setup

# Access Vault UI
open http://vault.127-0-0-1.nip.io
```

#### 2. Percona PostgreSQL Setup
```bash
# Install operator and deploy cluster with TDE
task percona:setup
```

#### 3. Verify TDE
```bash
# Verify TDE is working
task percona:tde:verify

# Check cluster status
task percona:status
```

## Documentation

### Comprehensive Guides

1. **[Setup Guide](docs/SETUP-GUIDE.md)** - Complete step-by-step setup guide with detailed explanations and Mermaid diagrams covering:
   - Architecture overview with visual diagrams
   - Vault setup and initialization process
   - Percona PostgreSQL deployment
   - TDE configuration workflow
   - Data encryption flow diagrams
   - Key hierarchy and management
   - Verification procedures
   - Troubleshooting guide

2. **[Separate Clusters Setup](docs/SEPARATE-CLUSTERS.md)** - Comprehensive guide for running Vault and PostgreSQL on separate Kubernetes clusters:
   - Architecture comparison (single vs separate clusters)
   - Network connectivity challenges and solutions
   - Multiple setup options (LoadBalancer, NodePort, Ingress, VPN/Service Mesh)
   - Step-by-step external Vault configuration with TLS
   - Security considerations for cross-cluster communication
   - Certificate management and validation
   - Migration strategies from single to separate clusters
   - High availability setup

### Quick Reference

For manual TDE reinitialization:

```bash
# Run the TDE initialization
task percona:tde:init
```

## Creating Encrypted Tables

Connect to PostgreSQL and create tables with encryption:

```sql
-- Create encrypted table
CREATE TABLE sensitive_data (
    id SERIAL PRIMARY KEY,
    customer_name TEXT,
    ssn TEXT,
    credit_card TEXT,
    created_at TIMESTAMP DEFAULT NOW()
) USING tde_heap;

-- Verify encryption
SELECT pg_tde_is_encrypted('sensitive_data');
-- Returns: t (true)

-- Check table access method
SELECT c.relname, am.amname
FROM pg_class c
JOIN pg_am am ON c.relam = am.oid
WHERE c.relname = 'sensitive_data';
-- Returns: sensitive_data | tde_heap
```

## Key Management

### Check Key Providers
```sql
SELECT * FROM pg_tde_list_all_global_key_providers();
```

### Check Default Encryption Key
```sql
SELECT * FROM pg_tde_default_key_info();
```

### List All Encrypted Tables
```sql
SELECT c.relname, am.amname
FROM pg_class c
JOIN pg_am am ON c.relam = am.oid
WHERE am.amname = 'tde_heap';
```

## Taskfile Commands

### Vault Commands
- `task vault:install` - Install Vault using Helm
- `task vault:init` - Initialize Vault (creates unseal keys)
- `task vault:unseal` - Unseal Vault
- `task vault:status` - Check Vault pod status
- `task vault:verify` - Verify Vault installation
- `task vault:ingress:apply` - Create ingress for Vault UI
- `task vault:setup` - Complete Vault setup

### Terraform Commands
- `task terraform:install` - Install Terraform using devbox
- `task terraform:init` - Initialize Terraform
- `task terraform:plan` - Plan Terraform changes
- `task terraform:apply` - Apply Terraform configuration
- `task terraform:output` - Show Terraform outputs

### Percona Commands
- `task percona:install` - Install Percona PostgreSQL Operator
- `task percona:status` - Check cluster status
- `task percona:connect` - Get connection info
- `task percona:logs` - View cluster logs
- `task percona:tde:init` - Initialize TDE
- `task percona:tde:verify` - Verify TDE is working
- `task percona:setup` - Complete Percona setup with TDE

### Complete Setup
- `task all:setup` - Setup everything (Vault + Percona + TDE)

## Configuration Files

### Vault
- `vault/vault-values.yaml` - Helm values for Vault
- `vault/vault-ingress.yaml` - Ingress configuration
- `vault/vault-init-keys.txt` - Unseal keys and root token (generated)

### Terraform
- `vault-terraform/main.tf` - Vault resources configuration
- `vault-terraform/provider.tf` - Terraform provider config
- `vault-terraform/variables.tf` - Variables
- `vault-terraform/outputs.tf` - Outputs

### Percona
- `percona/tde-cluster.yaml` - PostgreSQL cluster with TDE enabled
- `percona/working-cluster.yaml` - Basic cluster without TDE
- `percona/operator-values.yaml` - Operator Helm values
- `percona/init-tde.sh` - TDE initialization script
- `percona/verify-tde.sh` - TDE verification script
- `percona/TDE-SETUP.md` - Detailed TDE setup documentation

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐              ┌──────────────────────┐ │
│  │   Vault      │              │  Percona PostgreSQL  │ │
│  │  (namespace: │◄─────────────┤  (namespace: percona)│ │
│  │   vault)     │  Key Mgmt    │                      │ │
│  │              │              │  ┌────────────────┐  │ │
│  │  - KV v2     │              │  │  pg-cluster    │  │ │
│  │  - Transit   │              │  │                │  │ │
│  │  - K8s Auth  │              │  │  pg_tde v2.0   │  │ │
│  └──────────────┘              │  │  PostgreSQL 17 │  │ │
│                                 │  └────────────────┘  │ │
│                                 └──────────────────────┘ │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Ingress (Traefik)                               │   │
│  │  http://vault.127-0-0-1.nip.io                  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## TDE How It Works

1. **Key Storage**: Encryption keys are stored in Vault's KV v2 secrets engine at `secret/tde/global-key`
2. **Authentication**: PostgreSQL authenticates to Vault using a token stored in `/tmp/vault/token.txt`
3. **Key Provider**: pg_tde is configured with `vault-provider` pointing to Vault
4. **Master Key**: A global master key `global-master-key` is created and set as default
5. **Table Encryption**: Tables created with `USING tde_heap` are automatically encrypted
6. **Transparent Decryption**: Data is transparently decrypted when accessed by authorized users

## Important Notes

1. **pg_tde uses KV v2**: Unlike some systems, pg_tde uses Vault's KV v2 secrets engine, not the Transit engine
2. **PostgreSQL 17 Required**: Use PostgreSQL 17.x images; 16.x had compatibility issues
3. **Manual Initialization**: TDE must be manually initialized after cluster deployment
4. **Token Security**: In production, use Kubernetes auth instead of static tokens
5. **Access Method**: Use `USING tde_heap` when creating encrypted tables

## Troubleshooting

### Check pg_tde is loaded
```bash
kubectl exec -n percona pg-cluster-instance1-6t9g-0 -c database -- \
  psql -U postgres -c "SHOW shared_preload_libraries;"
```

### Check extension is installed
```bash
kubectl exec -n percona pg-cluster-instance1-6t9g-0 -c database -- \
  psql -U postgres -c "\dx pg_tde"
```

### Verify Vault connectivity
```bash
kubectl exec -n percona pg-cluster-instance1-6t9g-0 -c database -- \
  curl -v http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

### Run full verification
```bash
./percona/verify-tde.sh
```

## Security Considerations

1. **Vault Unseal Keys**: Store unseal keys securely (currently in `vault/vault-init-keys.txt`)
2. **Root Token**: Rotate and secure the root token for production use
3. **Token Path**: Use Kubernetes auth method instead of file-based tokens in production
4. **Backup**: Ensure Vault data is backed up regularly
5. **Network Policies**: Implement network policies to restrict Vault access

## Testing TDE

A test table `encrypted_test` has been created with sample data:

```sql
SELECT * FROM encrypted_test;
-- Returns decrypted data

SELECT pg_tde_is_encrypted('encrypted_test');
-- Returns: t (true)
```

## Next Steps

1. **Create encrypted tables** for your application
2. **Test backup and restore** with encrypted data
3. **Implement proper secret management** (replace file-based token with K8s auth)
4. **Setup monitoring** for Vault and PostgreSQL
5. **Configure backup** retention and policies
6. **Test disaster recovery** procedures

## Resources

- [Percona PostgreSQL Operator Documentation](https://docs.percona.com/percona-operator-for-postgresql/)
- [pg_tde Extension](https://docs.percona.com/postgresql/latest/tde.html)
- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [PostgreSQL 17 Documentation](https://www.postgresql.org/docs/17/)

## Status

✓ Vault: Running and unsealed
✓ Percona PostgreSQL Operator: v2.8.0
✓ PostgreSQL Cluster: Ready (1 instance)
✓ TDE: Enabled with Vault integration
✓ Test Table: encrypted_test (verified encrypted)

**TDE is fully operational and ready for use!**
