#!/usr/bin/env bash
set -e

echo "Running fetch-clj-deps tests..."
echo ""

echo "Test 1: Basic fetch (with hash)"
nix-build test-fetch-clj-deps.nix -A test-basic-fetch --no-out-link > /dev/null 2>&1
echo "✓ Basic fetch passed"
echo ""

echo "Test 2: Custom prep command (string)"
nix-build test-fetch-clj-deps.nix -A test-custom-prep --no-out-link 2>&1 | grep -q "WARNING: Specified aliases are undeclared"
echo "✓ Custom prep command passed"
echo ""

echo "Test 3: Prep with srcRoot and aliases (attribute set)"
nix-build test-fetch-clj-deps.nix -A test-srcroot --no-out-link 2>&1 | grep -q "hash mismatch"
echo "✓ SrcRoot prep passed (hash mismatch expected)"
echo ""

echo "Test 4: Prep with aliases (attribute set)"
nix-build test-fetch-clj-deps.nix -A test-with-aliases --no-out-link 2>&1 | grep -q "lambdaisland/kaocha"
echo "✓ Aliases prep passed"
echo ""

echo "Test 5: Multiple preparations (list)"
OUTPUT=$(nix-build test-fetch-clj-deps.nix -A test-multi-prep --no-out-link 2>&1)
if echo "$OUTPUT" | grep -q "data.json" && echo "$OUTPUT" | grep -q "cheshire"; then
    echo "✓ Multi-prep passed"
else
    echo "✗ Multi-prep failed"
    exit 1
fi
echo ""

echo "Test 6: Multiple aliases (attribute set)"
nix-build test-fetch-clj-deps.nix -A test-multiple-aliases --no-out-link 2>&1 | grep -q "lambdaisland/kaocha"
echo "✓ Multiple aliases passed"
echo ""

echo "All core tests passed! ✓"
