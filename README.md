# Coolify CDN

A lightweight Go-based CDN for serving static JSON files with ETag support.

## Directory Structure

```
.
├── Dockerfile
├── main.go
├── go.mod
├── json/              # Place your JSON files here (supports subdirectories)
│   ├── file.json      # Served at /file.json
│   └── subdir/
│       └── data.json  # Served at /subdir/data.json
└── README.md
```

## Features

- **Recursive Directory Support**: Serves JSON files from nested subdirectories
- **Dynamic File Loading**: Automatically discovers and serves all `*.json` files
- **Configurable Redirects**: Customizable base domain for redirects via `BASE_FQDN`
- **ETag Support**: MD5-based ETag generation for efficient cache validation
- **CORS Enabled**: Full cross-origin request support with preflight handling
- **JSON MIME Types**: Proper Content-Type headers for JSON files
- **HTTP Caching**: Last-Modified headers and 304 Not Modified responses
- **Range Requests**: Support for partial content requests (Accept-Ranges: bytes)
- **Scratch-based**: Ultra-small image size (~10MB)
- **Multi-arch**: Compatible with AMD64 and ARM64 architectures
- **Health Check Endpoint**: Available at `/health`
- **Embedded Files**: JSON files embedded in binary for instant startup
- **HEAD Method**: Full support for HEAD requests

## Usage

1. Add your JSON files to the `json/` directory (supports nested directories):
```bash
# Root level files
echo '{"message": "Hello World"}' > json/example.json
echo '{"version": "1.0.0", "data": []}' > json/config.json

# Nested directories
mkdir -p json/api/v1
echo '{"endpoints": ["/users", "/posts"]}' > json/api/v1/routes.json
echo '{"database": "connected"}' > json/api/v1/health.json
```

2. Build the Docker image:
```bash
docker buildx build --platform linux/amd64,linux/arm64 --build-arg BASE_FQDN=yourdomain.com -t coolify-cdn .
```

3. Run the container:
```bash
docker run -p 8080:80 coolify-cdn  # (built with --build-arg BASE_FQDN=yourdomain.com)
```

4. Test the implementation:
```bash
# Run tests
./test.sh 8080

# Or test manually:
# Health check
curl http://localhost:8080/health

# Access any JSON file (including nested paths)
curl http://localhost:8080/example.json
curl http://localhost:8080/config.json
curl http://localhost:8080/api/v1/routes.json
curl http://localhost:8080/status/health.json

# ETag caching works for all files
curl -i http://localhost:8080/example.json
curl -i -H 'If-None-Match: "ETAG_VALUE"' http://localhost:8080/example.json
```

## Configuration

### BASE_FQDN Environment Variable

The `BASE_FQDN` environment variable controls the domain used for redirects (root path and 404 errors). It defaults to `coolify.io` if not set.

**Options:**
- **Environment Variable**: Set `BASE_FQDN=yourdomain.com` when running the container
- **Build Argument**: Set `--build-arg BASE_FQDN=yourdomain.com` when building the image
- **Default**: `coolify.io`

**Examples:**
```bash
# Runtime configuration
docker run -e BASE_FQDN=mysite.com -p 8080:80 coolify-cdn

# Build-time configuration
docker build --build-arg BASE_FQDN=mysite.com -t coolify-cdn .
docker run -p 8080:80 coolify-cdn  # Uses mysite.com for redirects
```

## Health Check
The service provides a health check endpoint:
```bash
curl http://localhost:8080/health
```

## Testing
Run the test suite to verify all functionality:
```bash
# Test against running container on port 8080
./test.sh

# Test against different port/host
./test.sh 8081 myhost.com
```

The test script verifies:
- Health endpoint functionality
- JSON file serving with proper headers
- ETag caching (304 responses)
- CORS headers and preflight requests
- Root and 404 redirects
- Content-Type headers
- Cache-Control headers
