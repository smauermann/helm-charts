# PVC Backup Chart

A Helm chart for creating automated PVC backups using VolSync and Restic to Backblaze B2.

## Features

- **Automated daily backups** of Kubernetes PVCs
- **One-click restore** from any backup to a PVC
- **VolSync integration** with Restic backend
- **Backblaze B2 storage** with encryption
- **Configurable retention** policies (daily/weekly)
- **Point-in-time restore** from specific backup timestamps
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
| `backup.manual` | Manual trigger name; when set, schedule is ignored | `null` |
| `backup.retain.daily` | Daily backups to retain | `7` |
| `backup.retain.weekly` | Weekly backups to retain | `4` |
| `backup.pruneIntervalDays` | Prune interval in days | `7` |
| `backup.cacheCapacity` | Restic cache size | `"2Gi"` |
| `backup.cacheStorageClassName` | Storage class for cache | `"longhorn-single-replica"` |
| `backup.storageClassName` | Storage class for destination volumes | `"longhorn"` |
| `backup.volumeSnapshotClassName` | Volume snapshot class | `"longhorn-snapshot"` |
| `restore.enabled` | Enable restore functionality | `false` |
| `restore.destinationPVC` | PVC to restore data into | `""` (defaults to pvcName) |
| `restore.trigger` | Manual trigger name for restore | `"restore"` |
| `restore.restoreAsOf` | RFC-3339 timestamp for point-in-time restore | `""` |
| `restore.copyMethod` | Copy method for restore | `"Snapshot"` |
| `restore.cacheCapacity` | Cache size for restore | `""` (defaults to backup.cacheCapacity) |
| `restore.cacheStorageClassName` | Storage class for restore cache | `""` (defaults to backup.cacheStorageClassName) |
| `restore.storageClassName` | Storage class for restore destination volumes | `""` (defaults to backup.storageClassName) |
| `restic.runAsUser` | Security context user ID | `65534` |
| `restic.runAsGroup` | Security context group ID | `65534` |
| `restic.fsGroup` | Security context FS group | `65534` |
| `b2.secretStoreRef.kind` | Secret store kind | `"ClusterSecretStore"` |
| `b2.secretStoreRef.name` | Secret store name | `"onepassword-connect"` |
| `b2.secretKey` | Secret key in store | `"backblaze-volsync"` |

Use `restore.cacheStorageClassName` when the cache PVC should land on different storage than the restored data.

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

### Manual Backup Trigger
```yaml
appName: backup-fixture
pvcName: pgdata-backup-fixture-postgres-1
backup:
  trigger:
    manual: run-backup-now  # schedule defaults but is ignored when manual is set
```

### Different Storage Classes
```yaml
appName: myapp
pvcName: myapp-data
backup:
  cacheStorageClassName: fast-ssd-cache
  storageClassName: fast-ssd
  volumeSnapshotClassName: fast-ssd-snapshot
```

### Restore from Backup
```yaml
appName: jellyfin
pvcName: jellyfin-config
restore:
  enabled: true
  destinationPVC: jellyfin-config-restored
  trigger: restore-2024-01-15
```

### Point-in-time Restore
```yaml
appName: database
pvcName: postgres-data
restore:
  enabled: true
  destinationPVC: postgres-data-recovery
  trigger: restore-emergency
  restoreAsOf: "2024-01-15T10:30:00Z"
  copyMethod: Snapshot
```

## Created Resources

This chart creates:
- **ReplicationSource**: VolSync resource for backup scheduling
- **ExternalSecret**: Pulls B2 credentials from your secret store
- **ReplicationDestination** (when restore.enabled=true): VolSync resource for restoring data from backups

## Monitoring

The ReplicationSource includes labels for monitoring. You can create ServiceMonitor or similar resources to track backup status.

## Troubleshooting

### Backup Failures
Check the VolSync controller logs and ReplicationSource status:
```bash
kubectl describe replicationsource <appname>-data-b2
kubectl logs -n volsync-system deployment/volsync
```

### Restore Failures
Check the ReplicationDestination status and logs:
```bash
kubectl describe replicationdestination <appname>-restore-b2
kubectl logs -n volsync-system deployment/volsync
```

### Permission Issues
Ensure the security context settings match your cluster's security policies.

## Restore Workflow

1. **Enable restore** by setting `restore.enabled: true`
2. **Create destination PVC** (or use existing one via `restore.destinationPVC`)
3. **Deploy the chart** - this creates the ReplicationDestination resource
4. **Monitor restore progress**:
   ```bash
   kubectl get replicationdestination <appname>-restore-b2 -o yaml
   ```
5. **Verify completion** when `.status.lastManualSync` matches `.spec.trigger.manual`
6. **Disable restore** by setting `restore.enabled: false` and upgrading to clean up resources
