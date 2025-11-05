# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Coolify CDN is a lightweight Go-based CDN server that serves static JSON files with HTTP caching support. It's designed to be deployed as a minimal Docker container (scratch-based, ~10MB) with multi-architecture support (AMD64/ARM64).

## Core Architecture

### Embedded File System
- All JSON files in the `json/` directory are embedded into the Go binary at build time using `go:embed`
- The `loadJSONFiles()` function recursively walks the embedded filesystem on startup
- Files are loaded into memory maps (`files` and `etags`) with pre-calculated MD5 ETags
- URL paths mirror the directory structure (e.g., `json/api/v1/data.json` → `/api/v1/data.json`)

### Request Handling Flow
The main request handler (`handleRequest()`) processes requests in this order:
1. Sets CORS headers for all requests
2. Handles OPTIONS preflight requests (returns 204)
3. Root path (`/`) → redirects to `https://{BASE_FQDN}`
4. Health check (`/health`) → returns "healthy" with 200
5. Known files → serves JSON with ETag caching
6. Unknown files (404) → redirects to `https://{BASE_FQDN}{RequestURI}`

### Caching Strategy
- MD5-based ETags are calculated once at startup for all files
- Client sends `If-None-Match` header with ETag
- Server returns 304 Not Modified if ETag matches
- Also sets `Last-Modified` and supports Range requests via `http.ServeContent()`

## Development Commands

### Building
```bash
# Local build
go build -o coolify-cdn main.go

# Docker build (multi-arch)
docker buildx build --platform linux/amd64,linux/arm64 -t coolify-cdn .

# Docker build with custom redirect domain
docker buildx build --platform linux/amd64,linux/arm64 --build-arg BASE_FQDN=yourdomain.com -t coolify-cdn .
```

### Running
```bash
# Run locally (requires json/ directory)
go run main.go

# Run with custom BASE_FQDN
BASE_FQDN=example.com go run main.go

# Run Docker container
docker run -p 8080:80 coolify-cdn

# Run with runtime BASE_FQDN override
docker run -e BASE_FQDN=mysite.com -p 8080:80 coolify-cdn
```

### Testing
```bash
# Run full test suite against localhost:8080
./test.sh

# Test against custom port
./test.sh 8081

# Test against custom host and port
./test.sh 8081 example.com
```

The test script (`test.sh`) verifies all functionality including health checks, JSON serving, ETag caching, CORS, redirects, and HTTP headers.

## Configuration

### BASE_FQDN
The only configurable parameter controls where root and 404 requests redirect:
- **Build-time**: `--build-arg BASE_FQDN=domain.com` (default: `coolify.io`)
- **Runtime**: `-e BASE_FQDN=domain.com` environment variable
- Used in `main.go:62-65` and `main.go:102,118`

## Adding New JSON Files

1. Place files in `json/` directory (supports nested subdirectories)
2. Rebuild the Docker image (files are embedded at build time)
3. Files automatically become available at their path (e.g., `json/data.json` → `/data.json`)

## Key Implementation Details

### Why Scratch Base Image
Uses `FROM scratch` for minimal attack surface and size. No shell, no package manager, just the statically-compiled binary and embedded files.

### Why Embed vs Runtime Loading
Files are embedded using `//go:embed json/*` because:
- Scratch containers have no filesystem to mount
- Faster startup (no disk I/O)
- Immutable deployments (files can't change at runtime)

### CORS Configuration
All responses include `Access-Control-Allow-Origin: *` to allow cross-origin requests from any domain. Handles OPTIONS preflight requests for complex CORS scenarios.
