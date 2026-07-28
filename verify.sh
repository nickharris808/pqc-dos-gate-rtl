#!/bin/sh
# Re-run every formal proof and assert the EXPECTED verdict for each.
#
# Three of these must SUCCEED and two must FAIL. The failures are the point: the
# naive datapath genuinely admits a counterexample, and the gate genuinely breaks
# when the admit-enable line is glitched. A script that only accepted successes
# would hide the fault-isolation result, which is the most useful thing here.
set -eu
cd "$(dirname "$0")/proofs"

expect_success() {
    out=$(yosys "$1.ys" 2>&1)
    if printf '%s' "$out" | grep -q "Induction step proven: SUCCESS"; then
        printf '  ok    %-24s proven (unbounded k-induction)\n' "$1"; return 0
    fi
    printf '  FAIL  %-24s expected SUCCESS\n' "$1"; return 1
}

expect_counterexample() {
    out=$(yosys "$1.ys" 2>&1)
    if printf '%s' "$out" | grep -q "model found: FAIL"; then
        printf '  ok    %-24s counterexample found, as expected\n' "$1"; return 0
    fi
    printf '  FAIL  %-24s expected a counterexample\n' "$1"; return 1
}

status=0
expect_success        prove_gated            || status=1
expect_success        prove_fault_gated      || status=1
expect_success        prove_fault_unbounded  || status=1
expect_counterexample prove_naive            || status=1
expect_counterexample prove_fault_admit      || status=1

if [ "$status" -eq 0 ]; then
    printf '\nAll five proofs produced their expected verdict.\n'
fi
exit "$status"
