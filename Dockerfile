# Build stage
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod file (go.sum may not exist for projects with no external deps)
COPY go.mod* go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go healthcheck.go ./
COPY json/ ./json/

# Build the binaries with optimizations for the target platform
ARG TARGETOS TARGETARCH BASE_FQDN=coolify.io
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o coolify-cdn main.go
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o healthcheck healthcheck.go

# Final stage
FROM scratch

# Copy the binaries from builder stage
COPY --from=builder /app/coolify-cdn /coolify-cdn
COPY --from=builder /app/healthcheck /healthcheck

# Set the base FQDN environment variable
ARG BASE_FQDN=coolify.io
ENV BASE_FQDN=$BASE_FQDN

# Expose port 80
EXPOSE 80

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/healthcheck"]

# Run the binary
CMD ["/coolify-cdn"]