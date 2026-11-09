#!/bin/bash
# Grade tests written for spec.md: they must pass on the original and the
# refactored implementation, and fail on every buggy one.
# Usage: grade.sh WORKDIR    (WORKDIR contains tests/test_pricing.py)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${1:?usage: grade.sh WORKDIR}"
[ -f "$WORK/tests/test_pricing.py" ] || { echo "no tests/test_pricing.py in $WORK"; exit 2; }

ok=1
for impl in "$HERE"/impl_*.py; do
    name="$(basename "$impl" .py)"; name="${name#impl_}"
    tmp="$(mktemp -d /tmp/grade-pricing.XXXXXX)"
    cp "$impl" "$tmp/pricing.py" && cp -R "$WORK/tests" "$tmp/tests"
    out="$(cd "$tmp" && /usr/bin/python3 -m unittest discover -s tests 2>&1)"; status=$?
    ran="$(echo "$out" | sed -n 's/^Ran \([0-9]*\) test.*/\1/p')"
    rm -rf "$tmp"
    if [ "${ran:-0}" -eq 0 ]; then result="no tests ran"; ok=0
    elif [[ "$name" == buggy_* ]]; then
        [ $status -ne 0 ] && result="caught (tests failed, as they should)" || { result="MISSED (tests passed on buggy code)"; ok=0; }
    else
        [ $status -eq 0 ] && result="passed" || { result="BROKE (tests failed on correct code)"; ok=0; }
    fi
    printf '%-18s %s\n' "$name" "$result"
done
[ $ok -eq 1 ] && echo "PASS" || echo "FAIL"
[ $ok -eq 1 ]
