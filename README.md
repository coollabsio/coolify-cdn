# Coolify CDN

A simple nginx-based CDN for serving static JSON files with ETag support.

## Directory Structure

```
.
├── Dockerfile
├── nginx.conf
├── json/              # Place your JSON files here
│   ├── example.json
│   └── data/
│       └── items.json
└── README.md
```

## Features

- **ETag Support**: Automatic ETag generation for cache validation
- **CORS Enabled**: Allows cross-origin requests
- **JSON MIME Types**: Proper Content-Type headers for JSON files
- **Alpine-based**: Small image size (~40MB)
- **Health Check Endpoint**: Available at `/health`

## Usage

1. Create a `json/` directory and add your files:
```bash
mkdir -p json
echo '{"message": "Hello World"}' > json/example.json
```

2. Build the Docker image:
```bash
docker build -t coolify-cdn .
```

3. Run the container:
```bash
docker run -p 8080:80 coolify-cdn
```

4. Test the endpoint:
```bash
# First request - gets full response with ETag
curl -i http://localhost:8080/example.json

# Second request with ETag - gets 304 Not Modified if unchanged
curl -i -H 'If-None-Match: "ETAG_VALUE"' http://localhost:8080/example.json
```

## Configuration

### nginx.conf

The nginx configuration includes:
- ETag support enabled
- CORS headers for CDN usage
- Cache-Control headers
- Proper JSON MIME types
- OPTIONS request handling for CORS preflight

### Dockerfile

Uses `nginx:alpine` as base image and:
- Copies custom nginx configuration
- Copies all files from `json/` directory to nginx html root
- Exposes port 80

## Development

To update files without rebuilding:
```bash
docker run -p 8080:80 -v $(pwd)/json:/usr/share/nginx/html coolify-cdn
```

## Health Check

The service provides a health check endpoint:
```bash
curl http://localhost:8080/health
```
