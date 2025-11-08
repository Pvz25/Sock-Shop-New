# Multi-stage build for minimal payment service
FROM golang:1.20-alpine AS builder

WORKDIR /build

# Copy source
COPY go.mod .
COPY main.go .

# Build binary (static compilation)
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o payment main.go

# Final minimal image
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /build/payment /payment

# Environment variables
ENV PORT=8080
ENV PAYMENT_GATEWAY_URL=""

# Expose port
EXPOSE 8080

# Run
ENTRYPOINT ["/payment"]
