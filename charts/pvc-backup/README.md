# PVC Backup Chart

A Helm chart that provisions automated PVC backups using VolSync and Restic. It targets S3-compatible storage endpoints and is validated against Backblaze B2.

## Features

- Automated or manual VolSync backups with Restic
- Hourly/daily/weekly retention windows with configurable pruning
- Point-in-time restore with optional file deletion safety guard
- Restore clean-up toggles to work around Longhorn cache issues
- Argo CD sync wave annotation to prioritize restore jobs before apps
- 1Password Connect (or any External Secrets provider) for credential management

## Prerequisites

- Kubernetes cluster with the VolSync operator
- Longhorn CSI driver (for snapshots) or another snapshot-capable CSI
- External Secrets Operator
- 1Password Connect (or compatible SecretStore/ClusterSecretStore)
- S3-compatible object storage (Backblaze B2 tested)

## Installation

```bash
helm repo add smauermann https://smauermann.github.io/helm-charts
helm install my-app-backup smauermann/pvc-backup \
  --set appName=myapp \
  --set backup.pvc.name=myapp-data
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `appName` | Application name appended to generated resources (required) | `""` |
| `argoSyncWave` | Argo CD sync wave applied to VolSync resources | `"-100"` |
| `backup.trigger.schedule` | Cron expression for automated backups | `"0 1 * * *"` |
| `backup.trigger.manual` | Manual trigger name; overrides schedule when set | `null` |
| `backup.retain.hourly` | Hourly backups retained | `0` |
| `backup.retain.daily` | Daily backups retained | `7` |
| `backup.retain.weekly` | Weekly backups retained | `4` |
| `backup.pruneIntervalDays` | Days between prune operations | `7` |
| `backup.cache.capacity` | Restic cache PVC size | `2Gi` |
| `backup.cache.storageClass` | Storage class for cache PVC | `longhorn-single-replica` |
| `backup.pvc.name` | Source PVC name (required) | `""` |
| `backup.pvc.storageClass` | Storage class for backup destination PVCs | `longhorn` |
| `backup.pvc.volumeSnapshotClass` | Snapshot class for source PVC | `longhorn-snapshot` |
| `restore.enabled` | Enable ReplicationDestination resources | `false` |
| `restore.trigger` | Restore trigger name | `"restore"` |
| `restore.restoreAsOf` | RFC-3339 timestamp for point-in-time restore | `""` |
| `restore.enableFileDeletion` | Delete files missing from snapshot during restore | `false` |
| `restore.cleanupCachePVC` | Delete restic cache PVC after restore | `false` |
| `restore.cleanupTempPVC` | Delete temporary restore PVC (when auto-managed) | `false` |
| `restore.pvc.name` | Destination PVC name (defaults to source) | `""` |
| `restore.pvc.size` | Destination PVC size (required when creating PVC) | `""` |
| `restore.pvc.storageClass` | Storage class for destination PVC | `""` |
| `restore.pvc.accessModes` | Access modes for destination PVC | `["ReadWriteOnce"]` |
| `restic.runAsUser` | Restic container user ID | `65534` |
| `restic.runAsGroup` | Restic container group ID | `65534` |
| `restic.fsGroup` | File system group ID for mounted volumes | `65534` |
| `s3.provider` | Identifier appended to repository names | `"b2"` |
| `s3.secretStoreRef.kind` | External Secrets store kind | `"ClusterSecretStore"` |
| `s3.secretStoreRef.name` | External Secrets store name | `"onepassword-connect"` |
| `s3.secretKey` | Key referencing stored credentials | `"backblaze-volsync"` |

Use `restore.cleanupCachePVC` and `restore.cleanupTempPVC` cautiously with Longhorn (see [VolSync issue #1504](https://github.com/backube/volsync/issues/1504)). Leave them at `false` when using Longhorn snapshots.

## Secret Structure

Provide credentials in your referenced secret store with the following keys:
- `RESTIC_PASSWORD`: Restic repository password
- `AWS_ACCESS_KEY_ID`: S3-compatible access key
- `AWS_SECRET_ACCESS_KEY`: S3-compatible secret key
- `AWS_DEFAULT_REGION`: Region identifier understood by the S3 API
- `AWS_S3_ENDPOINT`: Endpoint URL (e.g., `https://s3.us-west-004.backblazeb2.com`)
- `BUCKET_NAME`: Bucket containing the Restic repository

## Examples

### Basic Usage
```yaml
appName: jellyfin
backup:
  pvc:
    name: jellyfin-config
```

### Custom Schedule and Retention
```yaml
appName: database
backup:
  pvc:
    name: postgres-data
  trigger:
    schedule: "0 2 * * *"        # run daily at 02:00
  retain:
    hourly: 6
    daily: 14
    weekly: 8
```

### Manual Backup Only
```yaml
appName: backup-fixture
backup:
  pvc:
    name: pgdata-backup-fixture-postgres-1
  trigger:
    manual: run-backup-now
```

### Alternate Storage Classes
```yaml
appName: myapp
backup:
  pvc:
    name: myapp-data
    storageClass: fast-ssd
    volumeSnapshotClass: fast-ssd-snapshot
  cache:
    storageClass: fast-ssd-cache
```

### Restore from Backup
```yaml
appName: jellyfin
backup:
  pvc:
    name: jellyfin-config
restore:
  enabled: true
  trigger: restore-2025-01-15
  pvc:
    name: jellyfin-config-restored
    size: 50Gi
```

### Point-in-time Restore with File Deletion
```yaml
appName: database
backup:
  pvc:
    name: postgres-data
restore:
  enabled: true
  trigger: restore-emergency
  restoreAsOf: "2025-01-15T10:30:00Z"
  enableFileDeletion: true
  pvc:
    size: 1Ti
```

## Created Resources

This chart provisions:
- **ReplicationSource** for scheduled or manual backups
- **ExternalSecret** to pull S3 credentials into the cluster
- **ReplicationDestination** and **PersistentVolumeClaim** if `restore.enabled: true`

## Monitoring

ReplicationSource objects expose status fields that can be scraped by ServiceMonitor or alerting tools to track backup health.

## Troubleshooting

- **Backup failures**: `kubectl describe replicationsource <appname>-data-b2` and check VolSync controller logs.
- **Restore failures**: `kubectl describe replicationdestination <appname>-restore-b2` for status, and inspect VolSync logs.
- **Permission issues**: Validate security context overrides match your cluster policies.

## Restore Workflow

1. Set `restore.enabled: true`.
2. Provide `restore.pvc` attributes (or reference an existing PVC).
3. Upgrade/install the release to create the ReplicationDestination.
4. Monitor progress: `kubectl get replicationdestination <appname>-restore-b2 -o yaml`.
5. Confirm `.status.lastManualSync` matches `.spec.trigger`.
6. Disable restore and upgrade again to clean up temporary resources when finished.
