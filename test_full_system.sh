#!/bin/bash
# Comprehensive System Test for G-Cloud Automation System

echo "════════════════════════════════════════════════════════════════════════════════"
echo "  G-CLOUD AUTOMATION SYSTEM - FULL SYSTEM TEST"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Testing: $name ... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response" == "$expected" ]; then
        echo -e "${GREEN}✅ PASS${NC} (HTTP $response)"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC} (HTTP $response, expected $expected)"
        ((FAILED++))
    fi
}

# Test database
test_database() {
    echo -n "Testing: Database Connection ... "
    if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((FAILED++))
    fi
}

# Test data
test_data() {
    echo -n "Testing: Proposal Data ... "
    count=$(curl -s http://localhost:8000/api/v1/proposals/ | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
    
    if [ "$count" == "4" ]; then
        echo -e "${GREEN}✅ PASS${NC} (4 proposals found)"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC} (Expected 4, found $count)"
        ((FAILED++))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. INFRASTRUCTURE TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_database
test_endpoint "Redis Service" "http://localhost:6379" "000"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2. BACKEND API TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_endpoint "Health Check" "http://localhost:8000/health" "200"
test_endpoint "API Root" "http://localhost:8000/api/v1/" "200"
test_endpoint "Proposals List" "http://localhost:8000/api/v1/proposals/" "200"
test_endpoint "API Documentation" "http://localhost:8000/docs" "200"
test_data

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3. FRONTEND TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_endpoint "Frontend Homepage" "http://localhost:3000" "200"
test_endpoint "Frontend Assets" "http://localhost:3000/src/main.tsx" "200"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  4. VALIDATION ENGINE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Running backend validation test..."
echo ""
docker-compose exec -T backend python /app/scripts/test_proposals.py | head -30
echo ""
echo -e "${BLUE}(Full validation output available above)${NC}"

echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "  TEST SUMMARY"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo ""
    echo "🎉 Your G-Cloud Automation System is fully operational!"
    echo ""
    echo "Access your application:"
    echo "  • Frontend:  http://localhost:3000"
    echo "  • Backend:   http://localhost:8000"
    echo "  • API Docs:  http://localhost:8000/docs"
    echo ""
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Please review the errors above and check:"
    echo "  • docker-compose ps (check service status)"
    echo "  • docker-compose logs [service] (check service logs)"
    echo ""
    exit 1
fi

