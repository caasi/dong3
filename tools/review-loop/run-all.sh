#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$D"/test-*.sh; do echo "== $t =="; bash "$t" || rc=1; done
[ $rc = 0 ] && echo "ALL SUITES PASS" || { echo "SUITE FAILURES"; exit 1; }
