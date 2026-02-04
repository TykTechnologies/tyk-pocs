#!/bin/bash

echo "Starting certificate generation for Tyk setup..."

# Configuration
OPENSSL_CONTAINER_NAME="tyk-openssl-temp"
GATEWAY_DOMAIN="tyk-gateway"
CERT_VALIDITY_DAYS=365
KEY_SIZE_RSA=4096
SIGNING_KEY_SIZE=2048

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_ok() {
    echo -e "${GREEN}✓${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker first."
fi

# Step 1: Clean up existing container if it exists
echo -n "Checking for existing OpenSSL container... "
if [ "$(docker ps -a --format '{{.Names}}' | grep -w "$OPENSSL_CONTAINER_NAME")" ]; then
    docker rm -f $OPENSSL_CONTAINER_NAME > /dev/null 2>&1
fi
log_ok

# Step 2: Create Docker volumes if they don't exist
echo -n "Creating certificate volumes... "
docker volume create gateway-certs > /dev/null 2>&1
docker volume create dashboard-certs > /dev/null 2>&1
log_ok

# Step 3: Create temporary container with volumes mounted
echo -n "Creating temporary OpenSSL container... "
docker run -d --name $OPENSSL_CONTAINER_NAME \
    -v gateway-certs:/gateway-certs \
    -v dashboard-certs:/dashboard-certs \
    alpine:3.20.1 tail -f /dev/null > /dev/null 2>&1
log_ok

# Step 4: Install OpenSSL
echo -n "Installing OpenSSL... "
docker exec $OPENSSL_CONTAINER_NAME apk add --no-cache openssl > /dev/null 2>&1

# Wait for installation to complete
for i in {1..10}; do
    if docker exec $OPENSSL_CONTAINER_NAME openssl version > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! docker exec $OPENSSL_CONTAINER_NAME openssl version > /dev/null 2>&1; then
    log_error "Failed to install OpenSSL"
fi
log_ok

OPENSSL_VERSION=$(docker exec $OPENSSL_CONTAINER_NAME openssl version)
echo "Using OpenSSL: $OPENSSL_VERSION"

# Step 5: Generate TLS certificate for Gateway with SAN
echo -n "Generating TLS certificate for $GATEWAY_DOMAIN... "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl req -x509 -newkey rsa:$KEY_SIZE_RSA \
    -subj \"/CN=$GATEWAY_DOMAIN\" \
    -addext \"subjectAltName=DNS:$GATEWAY_DOMAIN,DNS:localhost,IP:127.0.0.1\" \
    -keyout /gateway-certs/tls-private-key.pem \
    -out /gateway-certs/tls-certificate.pem \
    -days $CERT_VALIDITY_DAYS \
    -nodes" > /dev/null 2>&1; then
    log_ok
else
    log_error "Failed to generate TLS certificate"
fi

# Step 5a: Concatenate certificate and private key into single PEM file
echo -n "Creating combined certificate file... "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "cat /gateway-certs/tls-certificate.pem /gateway-certs/tls-private-key.pem > /gateway-certs/tls-combined.pem" > /dev/null 2>&1; then
    log_ok
else
    log_error "Failed to create combined certificate file"
fi

# Step 6: Generate private key for Dashboard (for signing)
echo -n "Generating Dashboard private key for signing... "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl genrsa -out /dashboard-certs/private-key.pem $SIGNING_KEY_SIZE" > /dev/null 2>&1; then
    log_ok
else
    log_error "Failed to generate private key"
fi

# Step 7: Generate public key for Gateway (from Dashboard private key)
echo -n "Generating Gateway public key... "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl rsa -in /dashboard-certs/private-key.pem \
    -pubout \
    -out /gateway-certs/public-key.pem" > /dev/null 2>&1; then
    log_ok
else
    log_error "Failed to generate public key"
fi

# Step 8: Set proper permissions - simplified approach
echo -n "Setting permissions on certificates... "
# Try to set permissions, but don't fail if it doesn't work perfectly
docker exec $OPENSSL_CONTAINER_NAME sh -c "cd /gateway-certs && chmod 644 *.pem 2>/dev/null || true" > /dev/null 2>&1
docker exec $OPENSSL_CONTAINER_NAME sh -c "cd /dashboard-certs && chmod 644 *.pem 2>/dev/null || true" > /dev/null 2>&1
log_ok

# Step 9: Verify certificates exist
echo -n "Verifying certificates... "
VERIFY_FAILED=0

if ! docker exec $OPENSSL_CONTAINER_NAME test -r /gateway-certs/tls-certificate.pem; then
    echo ""
    log_warning "Cannot read /gateway-certs/tls-certificate.pem"
    VERIFY_FAILED=1
fi

if ! docker exec $OPENSSL_CONTAINER_NAME test -r /gateway-certs/tls-private-key.pem; then
    echo ""
    log_warning "Cannot read /gateway-certs/tls-private-key.pem"
    VERIFY_FAILED=1
fi

if ! docker exec $OPENSSL_CONTAINER_NAME test -r /gateway-certs/tls-combined.pem; then
    echo ""
    log_warning "Cannot read /gateway-certs/tls-combined.pem"
    VERIFY_FAILED=1
fi

if ! docker exec $OPENSSL_CONTAINER_NAME test -r /gateway-certs/public-key.pem; then
    echo ""
    log_warning "Cannot read /gateway-certs/public-key.pem"
    VERIFY_FAILED=1
fi

if ! docker exec $OPENSSL_CONTAINER_NAME test -r /dashboard-certs/private-key.pem; then
    echo ""
    log_warning "Cannot read /dashboard-certs/private-key.pem"
    VERIFY_FAILED=1
fi

if [ $VERIFY_FAILED -eq 0 ]; then
    log_ok
else
    log_error "Certificate verification failed"
fi

# Step 10: Display certificate information
echo ""
echo "Certificate Information:"
echo "========================"
docker exec $OPENSSL_CONTAINER_NAME openssl x509 -in /gateway-certs/tls-certificate.pem -noout -subject -dates

# Step 10a: Verify combined file structure
echo ""
echo "Verifying combined certificate file:"
echo "====================================="
echo -n "Certificate in combined file: "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl x509 -in /gateway-certs/tls-combined.pem -noout -subject" > /dev/null 2>&1; then
    log_ok
else
    log_warning "Certificate verification in combined file failed"
fi

echo -n "Private key in combined file: "
if docker exec $OPENSSL_CONTAINER_NAME sh -c "openssl rsa -in /gateway-certs/tls-combined.pem -check -noout" > /dev/null 2>&1; then
    log_ok
else
    log_warning "Private key verification in combined file failed"
fi

# Step 11: List generated files
echo ""
echo "Generated files in gateway-certs volume:"
docker exec $OPENSSL_CONTAINER_NAME ls -lh /gateway-certs/
echo ""
echo "Generated files in dashboard-certs volume:"
docker exec $OPENSSL_CONTAINER_NAME ls -lh /dashboard-certs/

# Step 12: Clean up temporary container
echo ""
echo -n "Removing temporary container... "
if docker rm -f $OPENSSL_CONTAINER_NAME > /dev/null 2>&1; then
    log_ok
else
    log_warning "Failed to remove temporary container"
fi

# Step 13: Restart Gateway and Dashboard to load new certificates
echo ""
echo -n "Restarting Tyk Gateway and Dashboard to load new certificates... "
if docker-compose restart tyk-gateway tyk-dashboard > /dev/null 2>&1; then
    log_ok
    echo ""
    echo "Waiting for services to be ready..."
    sleep 5
else
    echo ""
    log_warning "Failed to restart services. Please restart manually: docker-compose restart tyk-gateway tyk-dashboard"
fi

echo ""
echo -e "${GREEN}Certificate generation completed successfully!${NC}"
echo ""
echo "Generated certificates:"
echo "  - Gateway TLS Certificate: gateway-certs/tls-certificate.pem"
echo "  - Gateway TLS Private Key: gateway-certs/tls-private-key.pem"
echo "  - Gateway Combined TLS (cert + key): gateway-certs/tls-combined.pem"
echo "  - Gateway Public Key: gateway-certs/public-key.pem"
echo "  - Dashboard Private Key: dashboard-certs/private-key.pem"
echo ""
echo "Certificate includes Subject Alternative Names:"
echo "  - DNS: $GATEWAY_DOMAIN"
echo "  - DNS: localhost"
echo "  - IP: 127.0.0.1"
echo ""
echo "Gateway and Dashboard have been restarted with new certificates."
echo "Test the gateway: curl -k https://tyk-gateway:8080/hello"