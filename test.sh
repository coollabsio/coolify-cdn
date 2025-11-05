#!/bin/bash

# Test script for Coolify CDN 
# Usage: ./test.sh [port] [host]
# Default: port=8080, host=localhost

PORT=${1:-8080}
HOST=${2:-localhost}
BASE_URL="http://$HOST:$PORT"

echo "🧪 Testing Coolify CDN"
echo "📍 Target: $BASE_URL"
echo "────────────────────────────────────────"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_result() {
    local test_name="$1"
    local result="$2"
    local expected="$3"
    local actual="$4"

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ $test_name${NC}"
        echo -e "   Expected: $expected"
        echo -e "   Actual: $actual"
        ((FAILED++))
    fi
}

# Test 1: Health endpoint
echo -e "\n🏥 Testing Health Endpoint"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$BASE_URL/health")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//g')

if [ "$http_code" = "200" ] && [ "$body" = "healthy" ]; then
    test_result "Health endpoint returns 200 and 'healthy'" "PASS"
else
    test_result "Health endpoint returns 200 and 'healthy'" "FAIL" "200, healthy" "$http_code, $body"
fi

# Test 2: Health endpoint headers
echo -e "\n📋 Testing Health Endpoint Headers"
response=$(curl -s -I "$BASE_URL/health")
content_type=$(echo "$response" | grep -i "content-type" | tr -d '\r')
cors_origin=$(echo "$response" | grep -i "access-control-allow-origin" | tr -d '\r')

if echo "$content_type" | grep -q "text/plain"; then
    test_result "Health endpoint has correct Content-Type" "PASS"
else
    test_result "Health endpoint has correct Content-Type" "FAIL" "text/plain" "$content_type"
fi

if [ "$cors_origin" = "Access-Control-Allow-Origin: *" ]; then
    test_result "Health endpoint has CORS headers" "PASS"
else
    test_result "Health endpoint has CORS headers" "FAIL" "Access-Control-Allow-Origin: *" "$cors_origin"
fi

# Test 3: JSON endpoint
echo -e "\n📄 Testing JSON Endpoint"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$BASE_URL/releases.json")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//g' | tr -d '\r\n')

if [ "$http_code" = "200" ] && echo "$body" | grep -q '"url"'; then
    test_result "JSON endpoint returns 200 and valid JSON" "PASS"
else
    test_result "JSON endpoint returns 200 and valid JSON" "FAIL" "200, valid JSON" "$http_code, $body"
fi

# Test 4: JSON endpoint headers
echo -e "\n🏷️  Testing JSON Endpoint Headers"
response=$(curl -s -I "$BASE_URL/releases.json")
content_type=$(echo "$response" | grep -i "content-type" | tr -d '\r')
etag=$(echo "$response" | grep -i "etag" | tr -d '\r')
cache_control=$(echo "$response" | grep -i "cache-control" | tr -d '\r')
cors_origin=$(echo "$response" | grep -i "access-control-allow-origin" | tr -d '\r')

if echo "$content_type" | grep -q "application/json"; then
    test_result "JSON endpoint has correct Content-Type" "PASS"
else
    test_result "JSON endpoint has correct Content-Type" "FAIL" "application/json" "$content_type"
fi

if echo "$etag" | grep -i -q "etag:"; then
    test_result "JSON endpoint has ETag header" "PASS"
else
    test_result "JSON endpoint has ETag header" "FAIL" "ETag present" "$etag"
fi

if [ "$cache_control" = "Cache-Control: public, must-revalidate, max-age=600" ]; then
    test_result "JSON endpoint has correct Cache-Control" "PASS"
else
    test_result "JSON endpoint has correct Cache-Control" "FAIL" "public, must-revalidate, max-age=600" "$cache_control"
fi

if [ "$cors_origin" = "Access-Control-Allow-Origin: *" ]; then
    test_result "JSON endpoint has CORS headers" "PASS"
else
    test_result "JSON endpoint has CORS headers" "FAIL" "Access-Control-Allow-Origin: *" "$cors_origin"
fi

# Test 5: ETag caching
echo -e "\n🏷️  Testing ETag Caching"
# First get the ETag
response=$(curl -s -I "$BASE_URL/releases.json")
etag=$(echo "$response" | grep -i "etag" | tr -d '\r' | sed 's/ETag: //I')

# Then test with If-None-Match
response=$(curl -s -w "HTTPSTATUS:%{http_code}" -H "If-None-Match: $etag" "$BASE_URL/releases.json")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$http_code" = "304" ]; then
    test_result "ETag caching returns 304 Not Modified" "PASS"
else
    test_result "ETag caching returns 304 Not Modified" "FAIL" "304" "$http_code"
fi

# Test 6: Root redirect
echo -e "\n🏠 Testing Root Redirect"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" -I "$BASE_URL/")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
location=$(echo "$response" | grep -i "location" | tr -d '\r')

if [ "$http_code" = "302" ] && echo "$location" | grep -q "https://"; then
    test_result "Root path redirects to configured domain" "PASS"
else
    test_result "Root path redirects to configured domain" "FAIL" "302, https://<domain>" "$http_code, $location"
fi

# Test 7: 404 redirect
echo -e "\n❓ Testing 404 Redirect"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" -I "$BASE_URL/nonexistent.json")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
location=$(echo "$response" | grep -i "location" | tr -d '\r')

if [ "$http_code" = "302" ] && echo "$location" | grep -q "https://" && echo "$location" | grep -q "nonexistent.json"; then
    test_result "404 redirects to configured domain with path" "PASS"
else
    test_result "404 redirects to configured domain with path" "FAIL" "302, https://<domain>/nonexistent.json" "$http_code, $location"
fi

# Test 8: OPTIONS request (CORS preflight)
echo -e "\n🌐 Testing CORS Preflight"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X OPTIONS "$BASE_URL/releases.json")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$http_code" = "204" ]; then
    test_result "OPTIONS request returns 204 No Content" "PASS"
else
    test_result "OPTIONS request returns 204 No Content" "FAIL" "204" "$http_code"
fi

# Test 9: HEAD request
echo -e "\n📋 Testing HEAD Request"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" -I "$BASE_URL/releases.json")
http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$http_code" = "200" ]; then
    test_result "HEAD request returns 200 OK" "PASS"
else
    test_result "HEAD request returns 200 OK" "FAIL" "200" "$http_code"
fi

# Summary
echo -e "\n────────────────────────────────────────"
echo -e "📊 Test Summary:"
echo -e "   ${GREEN}Passed: $PASSED${NC}"
echo -e "   ${RED}Failed: $FAILED${NC}"
echo -e "   Total: $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! The CDN is working correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please check the implementation.${NC}"
    exit 1
fi