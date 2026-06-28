#!/bin/sh
scenario="$1"
nix build ".#nixosTestConfigurations.$scenario" --no-link -L >/tmp/test-result.log 2>&1
exit_code=$?
tail -30 /tmp/test-result.log
echo "EXIT_CODE=$exit_code"
