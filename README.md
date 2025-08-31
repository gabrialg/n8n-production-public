# N8N Production Container v4 - Ultra-Lean Architecture

## Overview
Ultra-lean N8N production container with native API key support for fastest possible boot times.

## Features
- **Boot Time**: 25-50 seconds (fastest version)
- **Architecture**: Zero installation overhead using N8N native persistence
- **Security**: No secrets embedded in image layers
- **Access**: Via Cloudflare tunnel integration

## Container Registry
This image is built and hosted at:
- **GitHub Container Registry**: `ghcr.io/gabrialg/n8n-production-public:v4`
- **Public Access**: Available for RunPod deployment

## Environment Variables (Set in RunPod Template)
- `TUNNEL_ID`: Your Cloudflare tunnel UUID
- `CF_HOSTNAME`: Your domain hostname  
- `CF_TUNNEL_JSON_B64`: Your base64-encoded tunnel credentials
- `N8N_API_KEY`: Your N8N API key for persistence

## Quick Deploy
Use RunPod template with:
- **Image**: `ghcr.io/gabrialg/n8n-production-public:v4`
- **CPU + 8GB Memory**
- **Environment variables configured**

🤖 Generated with [Claude Code](https://claude.ai/code)