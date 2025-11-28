# Percona PostgreSQL TDE Setup with Vault Integration

## Overview
This document describes the successful setup of Transparent Data Encryption (TDE) for Percona PostgreSQL using HashiCorp Vault as the key provider.

## Components Deployed
- HashiCorp Vault v0.31.0 (standalone mode with file storage)
- Percona PostgreSQL Operator v2.8.0
- PostgreSQL 17.6-1 with pg_tde extension v2.0

## Vault Configuration

### Access
- URL: http://vault.127-0-0-1.nip.io
- Root Token: Stored in `vault/vault-init-keys.txt`
- Unseal Keys: Stored in `vault/vault-init-keys.txt` (5 keys, threshold 3)

### Key Storage
- Secrets Engine: KV v2
- Mount Path: `secret/`
- TDE Key Path: `secret/data/tde/global-key`

## PostgreSQL Cluster Configuration

### Cluster Details
- Name: pg-cluster
- Namespace: percona
- PostgreSQL Version: 17.6-1
- Replicas: 1

### TDE Configuration
The cluster is configured with pg_tde via Patroni dynamic configuration:

```yaml
patroni:
  dynamicConfiguration:
    postgresql:
      parameters:
        shared_preload_libraries: "pg_tde"
```

## TDE Initialization Steps

### 1. Create Vault Token Secret
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: percona
type: Opaque
stringData:
  token: "YOUR_VAULT_ROOT_TOKEN"
EOF
```

### 2. Copy Token to PostgreSQL Pod
```bash
kubectl exec -n percona pg-cluster-instance1-6t9g-0 -c database -- mkdir -p /tmp/vault
kubectl exec -n percona pg-cluster-instance1-6t9g-0 -c database -- sh -c "echo 'YOUR_VAULT_ROOT_TOKEN' > /tmp/vault/token.txt"
```

### 3. Initialize pg_tde Extension
```sql
CREATE EXTENSION IF NOT EXISTS pg_tde;
```

### 4. Configure Vault as Key Provider
```sql
SELECT pg_tde_add_global_key_provider_vault_v2(
  'vault-provider',
  'http://vault.vault.svc.cluster.local:8200',
  'secret/data/tde/global-key',
  '/tmp/vault/token.txt',
  NULL
);
```

### 5. Create Master Encryption Key
```sql
SELECT pg_tde_create_key_using_global_key_provider('global-master-key', 'vault-provider');
```

### 6. Set Default Encryption Key
```sql
SELECT pg_tde_set_default_key_using_global_key_provider('global-master-key', 'vault-provider');
```

## Creating Encrypted Tables

To create a table with encryption:

```sql
CREATE TABLE encrypted_test (
  id SERIAL PRIMARY KEY,
  data TEXT,
  created_at TIMESTAMP DEFAULT NOW()
) USING tde_heap;
```

## Verification Commands

### Check Key Providers
```sql
SELECT * FROM pg_tde_list_all_global_key_providers();
```

Expected output:
```
 id |      name      |   type   |                                                                         options
----+----------------+----------+----------------------------------------------------------------------------------------------------------------------------------------------------------
 -1 | vault-provider | vault-v2 | {"url" : "http://vault.vault.svc.cluster.local:8200", "mountPath" : "secret/data/tde/global-key", "tokenPath" : "/tmp/vault/token.txt", "caPath" : null}
```

### Check Default Key
```sql
SELECT * FROM pg_tde_default_key_info();
```

Expected output:
```
     key_name      | provider_name  | provider_id |       key_creation_time
-------------------+----------------+-------------+-------------------------------
 global-master-key | vault-provider |          -1 | 2025-11-27 23:26:32.783149+00
```

### Verify Table Encryption
```sql
SELECT pg_tde_is_encrypted('table_name');
```

Returns `t` (true) if the table is encrypted.

### Check Table Access Method
```sql
SELECT c.relname, am.amname
FROM pg_class c
JOIN pg_am am ON c.relam = am.oid
WHERE c.relname = 'table_name';
```

Encrypted tables will show `tde_heap` as the access method.

## Important Notes

1. **pg_tde uses KV v2, NOT Transit engine**: Unlike some encryption solutions, pg_tde requires Vault's KV v2 secrets engine, not the Transit encryption engine.

2. **PostgreSQL Version**: Use PostgreSQL 17.x images. PostgreSQL 16.x images had issues with the startup scripts.

3. **Manual Initialization**: TDE configuration is not declarative in the PerconaPGCluster CRD. You must manually initialize pg_tde after cluster deployment.

4. **Token Management**: The Vault token is currently stored in `/tmp/vault/token.txt` inside the pod. For production, consider using Kubernetes auth method or other secure token delivery mechanisms.

5. **Access Method**: Tables must be created with `USING tde_heap` to enable encryption. The access method is `tde_heap`, not `tde_heap_basic`.

## Testing TDE

```sql
-- Create encrypted table
CREATE TABLE encrypted_test (
  id SERIAL PRIMARY KEY,
  data TEXT,
  created_at TIMESTAMP DEFAULT NOW()
) USING tde_heap;

-- Insert test data
INSERT INTO encrypted_test (data) VALUES
  ('This is sensitive data'),
  ('Another encrypted record'),
  ('Test TDE encryption');

-- Query data (decrypted automatically)
SELECT * FROM encrypted_test;

-- Verify encryption
SELECT pg_tde_is_encrypted('encrypted_test');
```

## Files Reference

- Cluster Configuration: `percona/tde-cluster.yaml`
- Working Cluster (no TDE): `percona/working-cluster.yaml`
- Vault Values: `vault/vault-values.yaml`
- Vault Ingress: `vault/vault-ingress.yaml`
- Vault Init Keys: `vault/vault-init-keys.txt`
- Terraform Config: `vault-terraform/`

## Taskfile Commands

- `task vault:install` - Install Vault
- `task vault:init` - Initialize Vault
- `task vault:unseal` - Unseal Vault
- `task percona:install` - Install Percona Operator
- `task percona:deploy` - Deploy PostgreSQL cluster
