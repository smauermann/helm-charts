# PVC Backup Chart

A Helm chart for creating automated PVC backups using VolSync and Restic to Backblaze B2.

## Features

- **Automated daily backups** of Kubernetes PVCs
- **VolSync integration** with Restic backend
- **Backblaze B2 storage** with encryption
- **Configurable retention** policies (daily/weekly)
- **1Password integration** for secure credential management
- **Longhorn snapshot support** for consistent backups

## Prerequisites

- Kubernetes cluster with VolSync operator installed
- Longhorn CSI driver (for snapshots)
- External Secrets Operator
- 1Password Connect (or compatible secret store)
- Backblaze B2 bucket configured

## Installation

```bash
helm repo add smauermann https://smauermann.github.io/helm-charts
helm install my-app-backup smauermann/pvc-backup \
  --set appName=myapp \
  --set pvcName=myapp-data
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `appName` | Application name (used in resource naming) | `""` (required) |
| `pvcName` | Name of PVC to backup | `""` (required) |
| `backup.schedule` | Backup cron schedule | `"0 1 * * *"` |
| `backup.retain.daily` | Daily backups to retain | `7` |
| `backup.retain.weekly` | Weekly backups to retain | `4` |
| `backup.pruneIntervalDays` | Prune interval in days | `7` |
| `backup.cacheCapacity` | Restic cache size | `"2Gi"` |
| `backup.storageClassName` | Storage class for cache | `"longhorn"` |
| `backup.volumeSnapshotClassName` | Volume snapshot class | `"longhorn-snapshot"` |
| `restic.runAsUser` | Security context user ID | `65534` |
| `restic.runAsGroup` | Security context group ID | `65534` |
| `restic.fsGroup` | Security context FS group | `65534` |
| `b2.secretStoreRef.kind` | Secret store kind | `"ClusterSecretStore"` |
| `b2.secretStoreRef.name` | Secret store name | `"onepassword-connect"` |
| `b2.secretKey` | Secret key in store | `"backblaze-volsync"` |

## Secret Structure

The chart expects a secret in your secret store with the following keys:
- `RESTIC_PASSWORD`: Password for Restic repository encryption
- `AWS_ACCESS_KEY_ID`: Backblaze B2 application key ID
- `AWS_SECRET_ACCESS_KEY`: Backblaze B2 application key
- `AWS_DEFAULT_REGION`: AWS region (can be any valid region)
- `AWS_S3_ENDPOINT`: Backblaze B2 S3-compatible endpoint
- `BUCKET_NAME`: Name of your B2 bucket

## Examples

### Basic Usage
```yaml
appName: jellyfin
pvcName: jellyfin-config
```

### Custom Schedule and Retention
```yaml
appName: database
pvcName: postgres-data
backup:
  schedule: "0 2 * * *"  # 2 AM daily
  retain:
    daily: 14
    weekly: 8
```

### Different Storage Classes
```yaml
appName: myapp
pvcName: myapp-data
backup:
  storageClassName: fast-ssd
  volumeSnapshotClassName: fast-ssd-snapshot
```

## Created Resources

This chart creates:
- **ReplicationSource**: VolSync resource for backup scheduling
- **ExternalSecret**: Pulls B2 credentials from your secret store

## Monitoring

The ReplicationSource includes labels for monitoring. You can create ServiceMonitor or similar resources to track backup status.

## Troubleshooting

### Backup Failures
Check the VolSync controller logs and ReplicationSource status:
```bash
kubectl describe replicationsource <appname>-data-b2
kubectl logs -n volsync-system deployment/volsync
```

### Permission Issues
Ensure the security context settings match your cluster's security policies.