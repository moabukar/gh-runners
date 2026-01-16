# Developer Usage Guide

## Quick Start

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - run: make build
```

## Available Labels

- `self-hosted` (required)
- `linux`
- `x64`
- `{company}` (your prefix)

## Pre-installed Tools

- Docker (with buildx)
- AWS CLI v2
- Terraform 1.7.x
- Node.js 20.x
- Python 3.x
- Go 1.22.x
- kubectl, Helm
- Trivy

## Best Practices

✅ Use OIDC for AWS credentials
✅ Set job timeouts
✅ Use caching

❌ Don't store secrets in env vars
❌ Don't assume persistent state
❌ Don't run untrusted code from forks

## Troubleshooting

**Job stuck in queued**: Check runner labels match exactly

**Slow startup**: First job takes 60-90s (cold start)
