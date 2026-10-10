#!/usr/bin/env bash
# shellcheck shell=bash
#
# Behaviour lock for the AU-English Vale rules.
#
# Vale 3.17.1 (nixpkgs) has no `vale test` subcommand, so this script plays that
# role: it lints the fixtures under ./fixtures and asserts the expected result.
# The dictionary must already be installed at
# ci/vale/styles/config/dictionaries/en_AU.{dic,aff} (see ../install-dictionaries.sh).
#
# Usage: ci/vale/test/run.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cfg="$here/.vale.ini"
fixtures="$here/fixtures"
vale_bin=${VALE_BIN:-vale}
status=0

vale() { "$vale_bin" --config "$cfg" --no-wrap "$@"; }

# 1. US fixture must exit non-zero and flag every US form.
set +e
us_out=$(vale "$fixtures/us-spelling.md" 2>&1)
us_rc=$?
set -e
if [ "$us_rc" -eq 0 ]; then
  echo "FAIL: us-spelling.md exited 0 (expected non-zero)"
  status=1
fi
for w in behavior color customize optimize realize centralize authorize synchronize analyze; do
  if ! grep -qF "'$w' is not Australian English spelling." <<<"$us_out"; then
    echo "FAIL: no alert for '$w'"
    status=1
  fi
done

# 2. AU fixture must be clean.
set +e
au_out=$(vale "$fixtures/au-spelling.md" 2>&1)
au_rc=$?
set -e
if [ "$au_rc" -ne 0 ]; then
  echo "FAIL: au-spelling.md exited $au_rc (expected 0)"
  echo "$au_out"
  status=1
fi

# 3. Ignored identifiers must be clean.
set +e
id_out=$(vale "$fixtures/ignored-identifiers.md" 2>&1)
id_rc=$?
set -e
if [ "$id_rc" -ne 0 ]; then
  echo "FAIL: ignored-identifiers.md exited $id_rc (expected 0)"
  echo "$id_out"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "vale AU-English tests: PASS"
else
  echo "vale AU-English tests: FAIL"
fi
exit "$status"
