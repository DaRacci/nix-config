#!/usr/bin/env bash
# QEMU VM integration test runner - sequential
# Usage: bash _run_tests.sh

set -o pipefail

HOSTS=("nixai" "nixmon" "nixdev" "nixio")
RESULTS=()

for host in "${HOSTS[@]}"; do
  echo ""
  echo "============================================"
  echo "=== BUILDING: ${host} ==="
  echo "============================================"
  start=$(date +%s)
  output=$(nix build ".#nixosTestConfigurations.${host}" --no-link -L 2>&1)
  exit_code=$?
  end=$(date +%s)
  elapsed=$((end - start))

  if [ $exit_code -eq 0 ]; then
    echo "=== PASS: ${host} (${elapsed}s) ==="
    RESULTS+=("PASS:${host}:${elapsed}s")
  else
    echo "=== FAIL: ${host} (exit code ${exit_code}, ${elapsed}s) ==="
    RESULTS+=("FAIL:${host}:exit=${exit_code}:${elapsed}s")
  fi
  # Print last 20 lines of output for context
  echo "--- Last 20 lines of ${host} output ---"
  echo "${output}" | tail -n 20
  echo "---"
done

echo ""
echo "============================================"
echo "=== SUMMARY ==="
echo "============================================"
for r in "${RESULTS[@]}"; do
  echo "$r"
done
