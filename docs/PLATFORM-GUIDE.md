# Platform Guide

Agile Flow supports multiple deployment platforms. Your choice is stored
in `.claude/PROJECT.md` and read by the `devops-engineer` and
`system-architect` agents.

## Supported Platforms

| Platform | Best For | Free Tier | Preview Envs |
|----------|----------|-----------|-------------|
| Render | Full-stack web apps, APIs | Yes | Yes (built-in) |
| Cloudflare | Edge computing, static sites | Yes | Yes (Workers) |
| Vercel | Frontend apps, Next.js | Yes | Yes (automatic) |
| Railway | Containers, databases | Trial | Yes |
| Fly.io | Global edge containers | Yes | Manual |

## Default: Render

This template ships configured for Render:

- `render.yaml` defines the service with preview environments enabled
- `deploy.yml` deploys to Render on merge to main
- `preview-deploy.yml` manages Render preview environments
- `rollback-production.yml` rolls back via Render API

## Choosing Your Platform

Run `/bootstrap-architecture` to select your platform. The choice is
written to `.claude/PROJECT.md`:

```markdown
## Platform
- **Hosting**: render
- **Selected**: 2026-02-17
```

## Switching Platforms

To switch platforms after initial setup:

1. Update `.claude/PROJECT.md` with the new platform
2. Replace the platform-specific workflow files:
   - `deploy.yml` -- production deployment
   - `preview-deploy.yml` -- PR preview environments
   - `preview-cleanup.yml` -- cleanup on PR close
3. Update `render.yaml` / `vercel.json` / `fly.toml` as needed
4. Update repository secrets in GitHub Settings

## Platform-Specific Setup

### Render

**Required secrets:**

| Secret | Where to Find |
|--------|--------------|
| `RENDER_API_KEY` | Render Dashboard > Account Settings > API Keys |
| `RENDER_SERVICE_ID` | Render Dashboard > Service > Settings |

**Configuration file:** `render.yaml`

### Cloudflare

**Required secrets:**

| Secret | Where to Find |
|--------|--------------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare Dashboard > Profile > API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare Dashboard > Overview (sidebar) |

**Configuration file:** `wrangler.toml`

### Vercel

**Required secrets:**

| Secret | Where to Find |
|--------|--------------|
| `VERCEL_TOKEN` | Vercel Dashboard > Settings > Tokens |
| `VERCEL_ORG_ID` | Vercel Dashboard > Settings > General |
| `VERCEL_PROJECT_ID` | Vercel Dashboard > Project > Settings |

**Configuration file:** `vercel.json`

### Railway

**Required secrets:**

| Secret | Where to Find |
|--------|--------------|
| `RAILWAY_TOKEN` | Railway Dashboard > Account > Tokens |

**Configuration file:** `railway.toml`

### Fly.io

**Required secrets:**

| Secret | Where to Find |
|--------|--------------|
| `FLY_API_TOKEN` | `fly tokens create deploy` |

**Configuration file:** `fly.toml`

## Adding a New Platform

1. Create deployment workflow in `.github/workflows/`
2. Add platform detection to `.claude/agents/devops-engineer.md`
3. Add setup instructions to this guide
4. Document required secrets in `docs/CI-CD-GUIDE.md`
