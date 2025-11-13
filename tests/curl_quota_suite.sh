#!/bin/bash

# =====================================================
# QUOTA SYSTEM CURL TEST SUITE
# =====================================================
# Comprehensive test suite for quota system
# Tests: Basic consumption, idempotency, quota limits,
# auto-refund, refund limits, premium bypass, initialization
# =====================================================

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base configuration
BASE_URL="${SUPABASE_URL:-http://localhost:54321}"
FUNCTIONS_URL="$BASE_URL/functions/v1"
REST_URL="$BASE_URL/rest/v1"
ANON_KEY="${SUPABASE_ANON_KEY:-anon_key_replace_me}"

# Test constants
TEST_DEVICE_ID="test_device_$(date +%s)"
TEST_IMAGE_URL="https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/noname-banana-images-prod/uploads/25199F28-E58B-432A-8EAD-60B511A7B553/76ACA520-7383-4C1D-A182-A1FFF59E878F.jpg"
TEST_PROMPT="enhance this image"

# Auto-detect Supabase URL or use localhost
if [ -z "$SUPABASE_URL" ]; then
    echo -e "${YELLOW}⚠️  SUPABASE_URL not set, using localhost:54321 (local development)${NC}"
    echo -e "${YELLOW}   To use production, set: export SUPABASE_URL=https://your-project.supabase.co${NC}\n"
fi

# Print header
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  QUOTA SYSTEM TEST SUITE${NC}"
echo -e "${BLUE}  Base URL: $BASE_URL${NC}"
echo -e "${BLUE}  Test Device ID: $TEST_DEVICE_ID${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

# Helper function to print test results
print_test_result() {
    local test_num=$1
    local description=$2
    local http_code=$3
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}TEST $test_num: $description${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}✅ HTTP Status: $http_code${NC}"
    elif [ "$http_code" -eq 429 ]; then
        echo -e "${YELLOW}⚠️  HTTP Status: $http_code (Quota Exceeded - Expected)${NC}"
    else
        echo -e "${RED}❌ HTTP Status: $http_code${NC}"
    fi
    echo ""
}

# =====================================================
# TEST 1: Basic Consumption
# =====================================================
TEST1_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
TEST1_BODY=$(cat <<EOF
{
  "device_id": "$TEST_DEVICE_ID",
  "user_id": null,
  "client_request_id": "$TEST1_ID",
  "image_url": "$TEST_IMAGE_URL",
  "prompt": "$TEST_PROMPT"
}
EOF
)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 1: Basic Consumption - First Request${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}Request ID: $TEST1_ID${NC}"
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST "$FUNCTIONS_URL/process-image" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "device-id: $TEST_DEVICE_ID" \
    -d "$TEST1_BODY" | tee >(jq '.' 2>/dev/null || cat)

TEST1_CODE=$(grep "HTTP_CODE:" /tmp/quota_test_response.json 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
echo -e "\n${BLUE}Expected: HTTP 200, quota increments${NC}\n"

# =====================================================
# TEST 2: Idempotent Request (Same Request ID)
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 2: Idempotent Request - Same Request ID${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}Using same Request ID: $TEST1_ID${NC}"
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST "$FUNCTIONS_URL/process-image" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "device-id: $TEST_DEVICE_ID" \
    -d "$TEST1_BODY" | tee >(jq '.' 2>/dev/null || cat)

echo -e "\n${BLUE}Expected: HTTP 200, idempotent=true, quota unchanged${NC}\n"

# =====================================================
# TEST 3: Quota Exceeded (6 Requests, Limit 5)
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 3: Quota Exceeded - Making 6 requests (limit is 5)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for i in {1..6}; do
    TEST3_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
    TEST3_BODY=$(cat <<EOF
{
  "device_id": "$TEST_DEVICE_ID",
  "user_id": null,
  "client_request_id": "$TEST3_ID",
  "image_url": "$TEST_IMAGE_URL",
  "prompt": "$TEST_PROMPT"
}
EOF
)
    
    echo -e "${YELLOW}Request $i of 6...${NC}"
    curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -X POST "$FUNCTIONS_URL/process-image" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "device-id: $TEST_DEVICE_ID" \
        -d "$TEST3_BODY" | tee >(jq '.' 2>/dev/null || cat)
    
    if [ "$i" -eq 6 ]; then
        echo -e "${BLUE}Expected: HTTP 429 on 6th request${NC}\n"
    fi
done

# =====================================================
# TEST 4: Auto Refund Trigger (Invalid Image URL)
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 4: Auto Refund Trigger - Invalid Image URL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

NEW_DEVICE_REFUND="test_device_refund_$(date +%s)"
TEST4_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
TEST4_BODY=$(cat <<EOF
{
  "device_id": "$NEW_DEVICE_REFUND",
  "user_id": null,
  "client_request_id": "$TEST4_ID",
  "image_url": "https://invalid-url-that-does-not-exist.com/nonexistent.jpg",
  "prompt": "$TEST_PROMPT"
}
EOF
)

echo -e "${YELLOW}Request ID: $TEST4_ID${NC}"
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST "$FUNCTIONS_URL/process-image" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "device-id: $NEW_DEVICE_REFUND" \
    -d "$TEST4_BODY" | tee >(jq '.' 2>/dev/null || cat)

echo -e "\n${BLUE}Expected: HTTP 200 (processing fails), auto-refund triggered${NC}\n"

# =====================================================
# TEST 5: Refund Limit (3 Failed Requests)
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 5: Refund Limit - Making 3 failed requests (limit is 2/day)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

NEW_DEVICE_LIMIT="test_device_limit_$(date +%s)"

for i in {1..3}; do
    TEST5_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
    TEST5_BODY=$(cat <<EOF
{
  "device_id": "$NEW_DEVICE_LIMIT",
  "user_id": null,
  "client_request_id": "$TEST5_ID",
  "image_url": "https://invalid-url-$i.example.com/fake.jpg",
  "prompt": "$TEST_PROMPT"
}
EOF
)
    
    echo -e "${YELLOW}Failed request $i of 3...${NC}"
    curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -X POST "$FUNCTIONS_URL/process-image" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ANON_KEY" \
        -H "device-id: $NEW_DEVICE_LIMIT" \
        -d "$TEST5_BODY" | tee >(jq '.' 2>/dev/null || cat)
done

echo -e "\n${BLUE}Expected: First 2 requests refunded, 3rd may hit refund limit${NC}\n"

# =====================================================
# TEST 6: Premium Bypass
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 6: Premium Bypass - is_premium=true${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TEST6_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
TEST6_BODY=$(cat <<EOF
{
  "device_id": "test_premium_device_$(date +%s)",
  "user_id": null,
  "client_request_id": "$TEST6_ID",
  "image_url": "$TEST_IMAGE_URL",
  "prompt": "$TEST_PROMPT",
  "is_premium": true
}
EOF
)

echo -e "${YELLOW}Request ID: $TEST6_ID${NC}"
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST "$FUNCTIONS_URL/process-image" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ANON_KEY" \
    -d "$TEST6_BODY" | tee >(jq '.' 2>/dev/null || cat)

echo -e "\n${BLUE}Expected: HTTP 200, quota_used = 0 (premium bypass)${NC}\n"

# =====================================================
# TEST 7: get_quota Initialization (Direct RPC Call)
# =====================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}TEST 7: get_quota RPC - Direct Initialization${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TEST7_DEVICE_ID="test_device_rpc_$(date +%s)"
TEST7_BODY=$(cat <<EOF
{
  "p_device_id": "$TEST7_DEVICE_ID",
  "p_user_id": null
}
EOF
)

echo -e "${YELLOW}Calling get_quota RPC function...${NC}\n"

curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST "$REST_URL/rpc/get_quota" \
    -H "Content-Type: application/json" \
    -H "apikey: $ANON_KEY" \
    -d "$TEST7_BODY" | tee >(jq '.' 2>/dev/null || cat)

echo -e "\n${BLUE}Expected: HTTP 200, initializes record if missing, returns quota${NC}\n"

# =====================================================
# SUMMARY
# =====================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TEST SUITE SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests completed!${NC}"
echo -e "\n${BLUE}Expected Results:${NC}"
echo -e "  ✅ Test 1: HTTP 200, quota_used = 1"
echo -e "  ✅ Test 2: HTTP 200, idempotent=true, quota_used unchanged"
echo -e "  ⚠️  Test 3: HTTP 429 on 6th request (quota exceeded)"
echo -e "  ⚠️  Test 4: HTTP 200, processing fails, auto-refund triggered"
echo -e "  ⚠️  Test 5: First 2 refunded, 3rd may hit refund limit (2/day)"
echo -e "  ✅ Test 6: HTTP 200, quota_used = 0 (premium bypass)"
echo -e "  ✅ Test 7: HTTP 200, initializes record if missing"
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${GREEN}✅ Test suite execution complete!${NC}\n"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review HTTP status codes above"
echo -e "  2. Check database for quota records"
echo -e "  3. Verify auto-refund trigger in logs"
echo -e "  4. Confirm idempotency worked correctly\n"
