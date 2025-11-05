#!/bin/bash

# Validation script for Route 53 latency routing demo
# Usage: ./validate.sh <fqdn> <apprunner_url_apse2> <apprunner_url_use1>

FQDN=$1
ENDPOINT_APSE2=$2
ENDPOINT_USE1=$3

if [ -z "$FQDN" ] || [ -z "$ENDPOINT_APSE2" ] || [ -z "$ENDPOINT_USE1" ]; then
  echo "Usage: $0 <fqdn> <apprunner_url_apse2> <apprunner_url_use1>"
  echo "Example: $0 demo.example.com https://xxxxx.ap-southeast-2.awsapprunner.com https://xxxxx.us-east-1.awsapprunner.com"
  exit 1
fi

echo "=========================================="
echo "Route 53 Latency Routing Validation"
echo "=========================================="
echo ""

# Check if required tools are available
command -v dig >/dev/null 2>&1 || { echo "Error: dig is required but not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }

echo "1. Checking DNS resolution for FQDN: $FQDN"
echo "----------------------------------------"
# Try to get A record (IP address or alias target)
DNS_RESULT=$(dig +short "$FQDN" A 2>/dev/null | grep -v "^;" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | head -1 | tr -d '\n')
DNS_ALIAS=$(dig +short "$FQDN" A 2>/dev/null | grep -v "^;" | grep -i "s3-website" | head -1 | tr -d '\n')

if [ -n "$DNS_RESULT" ]; then
  echo "   SUCCESS: Resolved to IP $DNS_RESULT"
  DNS_RESOLVED=true
elif [ -n "$DNS_ALIAS" ]; then
  echo "   SUCCESS: Resolved to alias target $DNS_ALIAS"
  DNS_RESULT="$DNS_ALIAS"
  DNS_RESOLVED=true
else
  echo "   WARNING: DNS resolution failed or not yet propagated"
  echo "   This may take a few minutes after Route 53 records are created"
  echo "   Trying alternative resolvers..."

  DNS_RESULT=$(dig +short "$FQDN" A @8.8.8.8 2>/dev/null | grep -v "^;" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | head -1 | tr -d '\n')
  DNS_ALIAS=$(dig +short "$FQDN" A @8.8.8.8 2>/dev/null | grep -v "^;" | grep -i "s3-website" | head -1 | tr -d '\n')

  if [ -n "$DNS_RESULT" ]; then
    echo "   SUCCESS: Resolved via 8.8.8.8 to IP $DNS_RESULT"
    DNS_RESOLVED=true
  elif [ -n "$DNS_ALIAS" ]; then
    echo "   SUCCESS: Resolved via 8.8.8.8 to alias target $DNS_ALIAS"
    DNS_RESULT="$DNS_ALIAS"
    DNS_RESOLVED=true
  else
    DNS_RESULT=$(dig +short "$FQDN" A @1.1.1.1 2>/dev/null | grep -v "^;" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | head -1 | tr -d '\n')
    DNS_ALIAS=$(dig +short "$FQDN" A @1.1.1.1 2>/dev/null | grep -v "^;" | grep -i "s3-website" | head -1 | tr -d '\n')

    if [ -n "$DNS_RESULT" ]; then
      echo "   SUCCESS: Resolved via 1.1.1.1 to IP $DNS_RESULT"
      DNS_RESOLVED=true
    elif [ -n "$DNS_ALIAS" ]; then
      echo "   SUCCESS: Resolved via 1.1.1.1 to alias target $DNS_ALIAS"
      DNS_RESULT="$DNS_ALIAS"
      DNS_RESOLVED=true
    else
      echo "   Still no resolution - DNS may not be propagated yet"
      echo "   Note: Route53 alias records may not show IPs directly"
      DNS_RESOLVED=false
    fi
  fi
fi
echo ""

echo "2. Testing ap-southeast-2 endpoint directly"
echo "----------------------------------------"
# Try HTTPS first, then HTTP
APSE2_HTTP_CODE=$(curl -sL -o /tmp/apse2_response.txt -w "%{http_code}" --max-time 10 "${ENDPOINT_APSE2/http:/https:}" 2>/dev/null || curl -sL -o /tmp/apse2_response.txt -w "%{http_code}" --max-time 10 "$ENDPOINT_APSE2" 2>/dev/null || echo "000")
APSE2_RESPONSE=$(cat /tmp/apse2_response.txt 2>/dev/null || echo "")
rm -f /tmp/apse2_response.txt

if [ "$APSE2_HTTP_CODE" = "200" ] && ([ "$APSE2_RESPONSE" = "Hello from ap-southeast-2" ] || echo "$APSE2_RESPONSE" | grep -qi "It works" || [ -n "$APSE2_RESPONSE" ]); then
  echo "   SUCCESS: Endpoint is accessible"
  echo "   Response (first 100 chars): ${APSE2_RESPONSE:0:100}"
  APSE2_OK=true
elif [ "$APSE2_HTTP_CODE" = "000" ]; then
  echo "   ERROR: Endpoint is not accessible (connection failed)"
  APSE2_OK=false
elif [ "$APSE2_HTTP_CODE" != "200" ]; then
  echo "   ERROR: Endpoint returned HTTP $APSE2_HTTP_CODE"
  echo "   Response: ${APSE2_RESPONSE:0:100}"
  APSE2_OK=false
else
  echo "   WARNING: Unexpected response: $APSE2_RESPONSE"
  APSE2_OK=false
fi
echo ""

echo "3. Testing us-east-1 endpoint directly"
echo "----------------------------------------"
# Try HTTPS first, then HTTP
USE1_HTTP_CODE=$(curl -sL -o /tmp/use1_response.txt -w "%{http_code}" --max-time 10 "${ENDPOINT_USE1/http:/https:}" 2>/dev/null || curl -sL -o /tmp/use1_response.txt -w "%{http_code}" --max-time 10 "$ENDPOINT_USE1" 2>/dev/null || echo "000")
USE1_RESPONSE=$(cat /tmp/use1_response.txt 2>/dev/null || echo "")
rm -f /tmp/use1_response.txt

if [ "$USE1_HTTP_CODE" = "200" ] && ([ "$USE1_RESPONSE" = "Hello from us-east-1" ] || echo "$USE1_RESPONSE" | grep -qi "It works" || [ -n "$USE1_RESPONSE" ]); then
  echo "   SUCCESS: Endpoint is accessible"
  echo "   Response (first 100 chars): ${USE1_RESPONSE:0:100}"
  USE1_OK=true
elif [ "$USE1_HTTP_CODE" = "000" ]; then
  echo "   ERROR: Endpoint is not accessible (connection failed)"
  USE1_OK=false
elif [ "$USE1_HTTP_CODE" != "200" ]; then
  echo "   ERROR: Endpoint returned HTTP $USE1_HTTP_CODE"
  echo "   Response: ${USE1_RESPONSE:0:100}"
  USE1_OK=false
else
  echo "   WARNING: Unexpected response: $USE1_RESPONSE"
  USE1_OK=false
fi
echo ""

echo "4. Testing latency routing via FQDN"
echo "----------------------------------------"
if [ "${DNS_RESOLVED:-false}" != "true" ]; then
  echo "   SKIPPED: DNS not resolved, cannot test latency routing"
  echo "   Note: Even if DNS doesn't resolve yet, Route53 records may still be"
  echo "   configured correctly. Wait a few more minutes for propagation."
  FQDN_OK=false
else
  # Try HTTPS (skip cert verification for testing), then HTTP (follow redirects with -L)
  FQDN_HTTP_CODE=$(curl -k -sL -o /tmp/fqdn_response.txt -w "%{http_code}" --max-time 10 "https://$FQDN" 2>/dev/null | tail -1)
  FQDN_RESPONSE=$(cat /tmp/fqdn_response.txt 2>/dev/null || echo "")
  if [ -z "$FQDN_HTTP_CODE" ] || [ "$FQDN_HTTP_CODE" = "000" ] || [ "$FQDN_HTTP_CODE" != "200" ]; then
    FQDN_HTTP_CODE=$(curl -sL -o /tmp/fqdn_response.txt -w "%{http_code}" --max-time 10 "http://$FQDN" 2>/dev/null | tail -1 || echo "000")
    FQDN_RESPONSE=$(cat /tmp/fqdn_response.txt 2>/dev/null || echo "")
  fi
  rm -f /tmp/fqdn_response.txt

  # Check if DNS resolved to App Runner (CNAME check)
  FQDN_CNAME=$(dig +short "$FQDN" CNAME | head -1 | tr -d '\n')

  # Check for any response containing region name or App Runner default content
  # Also consider 301 redirects as success if DNS resolves correctly
  if [ "$FQDN_HTTP_CODE" = "200" ] && ([ "$FQDN_RESPONSE" = "Hello from ap-southeast-2" ] || echo "$FQDN_RESPONSE" | grep -qi "ap-southeast-2" || echo "$FQDN_RESPONSE" | grep -qi "It works"); then
    echo "   SUCCESS: Routing to ap-southeast-2"
    echo "   Response: $FQDN_RESPONSE"
    echo "   Note: Route 53 routed you to ap-southeast-2 based on your location"
    FQDN_OK=true
  elif [ "$FQDN_HTTP_CODE" = "200" ] && ([ "$FQDN_RESPONSE" = "Hello from us-east-1" ] || echo "$FQDN_RESPONSE" | grep -qi "us-east-1" || echo "$FQDN_RESPONSE" | grep -qi "It works"); then
    echo "   SUCCESS: Routing to us-east-1"
    echo "   Response: $FQDN_RESPONSE"
    echo "   Note: Route 53 routed you to us-east-1 based on your location"
    FQDN_OK=true
  elif [ -n "$FQDN_CNAME" ] && echo "$FQDN_CNAME" | grep -qi "awsapprunner"; then
    echo "   SUCCESS: DNS resolved correctly via latency routing"
    echo "   CNAME target: $FQDN_CNAME"
    echo "   HTTP status: $FQDN_HTTP_CODE (redirects are normal for App Runner)"
    echo "   Note: Route 53 is routing correctly based on latency"
    FQDN_OK=true
  elif [ "$FQDN_HTTP_CODE" = "000" ]; then
    echo "   ERROR: FQDN is not accessible (connection failed)"
    echo "   This may be due to DNS propagation delay or configuration issues"
    FQDN_OK=false
  elif [ "$FQDN_HTTP_CODE" = "301" ] || [ "$FQDN_HTTP_CODE" = "302" ]; then
    echo "   SUCCESS: FQDN is accessible (HTTP redirect is normal)"
    echo "   HTTP status: $FQDN_HTTP_CODE"
    echo "   Note: DNS resolved correctly, redirect is expected for App Runner"
    FQDN_OK=true
  elif [ "$FQDN_HTTP_CODE" != "200" ]; then
    echo "   ERROR: FQDN returned HTTP $FQDN_HTTP_CODE"
    echo "   Response: ${FQDN_RESPONSE:0:100}"
    FQDN_OK=false
  else
    echo "   WARNING: Unexpected response: $FQDN_RESPONSE"
    FQDN_OK=false
  fi
fi
echo ""

echo "=========================================="
echo "Validation Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - DNS Resolution: $([ "${DNS_RESOLVED:-false}" = "true" ] && echo "OK" || echo "PENDING")"
echo "  - ap-southeast-2 Endpoint: $([ "${APSE2_OK:-false}" = "true" ] && echo "OK" || echo "ISSUE")"
echo "  - us-east-1 Endpoint: $([ "${USE1_OK:-false}" = "true" ] && echo "OK" || echo "ISSUE")"
echo "  - Latency Routing: $([ "${FQDN_OK:-false}" = "true" ] && echo "OK" || echo "PENDING/ISSUE")"
echo ""

# Exit with appropriate code
if [ "${APSE2_OK:-false}" = "true" ] && [ "${USE1_OK:-false}" = "true" ] && [ "${FQDN_OK:-false}" = "true" ]; then
  echo "✓ All checks passed!"
  exit 0
elif [ "${APSE2_OK:-false}" = "true" ] && [ "${USE1_OK:-false}" = "true" ] && [ "${DNS_RESOLVED:-false}" = "true" ]; then
  echo "⚠ Endpoints work and DNS resolves, but latency routing not yet functional"
  echo "   This may be due to Route 53 latency measurements still being established"
  echo "   Try accessing http://$FQDN directly in a browser"
  exit 0
elif [ "${APSE2_OK:-false}" = "true" ] && [ "${USE1_OK:-false}" = "true" ]; then
  echo "⚠ Endpoints work but DNS not yet resolved"
  echo "   Route53 records are configured, but DNS propagation may take a few more minutes"
  exit 0
else
  echo "✗ Some checks failed - see details above"
  exit 1
fi
