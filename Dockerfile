# Build stage
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod file (go.sum may not exist for projects with no external deps)
COPY go.mod* go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go ./
COPY json/ ./json/

# Build the binary with optimizations for the target platform
ARG TARGETOS TARGETARCH BASE_FQDN=coolify.io
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o coolify-cdn .

# Final stage
FROM scratch

# Copy the binary from builder stage
COPY --from=builder /app/coolify-cdn /coolify-cdn

# Set the base FQDN environment variable
ARG BASE_FQDN=coolify.io
ENV BASE_FQDN=$BASE_FQDN

# Expose port 80
EXPOSE 80

# Run the binary
CMD ["/coolify-cdn"]