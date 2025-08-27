# Helm Charts

A collection of Helm charts for various applications and use cases.

## Usage

```bash
helm repo add smauermann https://smauermann.github.io/helm-charts
helm repo update
```

## Available Charts

### pvc-backup

A Helm chart for creating VolSync-based PVC backups to Backblaze B2.

**Installation:**
```bash
helm install my-backup smauermann/pvc-backup \
  --set appName=myapp \
  --set pvcName=myapp-config
```

**Values:**
- `appName`: Name of your application (used in backup resource names)
- `pvcName`: Name of the PVC to backup
- `backup.schedule`: Backup schedule (default: "0 1 * * *" - daily at 1 AM)
- `backup.retain.daily`: Number of daily backups to retain (default: 7)
- `backup.retain.weekly`: Number of weekly backups to retain (default: 4)

See individual chart READMEs for detailed configuration options.

## Contributing

1. Make changes to charts in the `charts/` directory
2. Update chart version in `Chart.yaml`
3. Create a pull request
4. Charts are automatically published via GitHub Actions on release

## License

MIT