# pqc-dos-gate-rtl

[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![proofs](https://img.shields.io/badge/formal%20proofs-5-brightgreen.svg)](proofs/)
[![flipflops](https://img.shields.io/badge/synthesis-32%20flip--flops-blue.svg)](proofs/synth.ys)
[![solver](https://img.shields.io/badge/k--induction-unbounded-brightgreen.svg)](#)

**A synthesizable admission gate with a proven memory bound — and a measured answer
to "which gates do I actually have to protect?"**

32 flip-flops. Five Yosys proofs you can re-run in about a minute.

**📖 Full documentation, tutorial and conceptual guide: <https://nickharris808.github.io/pqc-toolkit/>**

---

## The interesting result is the fault isolation

Everyone proves their gate is safe. The useful question is what happens when an
attacker glitches it. Three proofs succeed and **two produce counterexamples**,
and the pattern is the finding:

| Proof | Verdict | What it means |
|---|---|---|
| `prove_gated` | **proven** | `resident ≤ CAP` for all reachable states, unbounded k-induction |
| `prove_naive` | **counterexample** | the ungated datapath genuinely violates the bound |
| `prove_fault_gated` | **proven** | the bound survives glitching the token-verify signal |
| `prove_fault_unbounded` | **proven** | it survives *unbounded* glitching of that signal |
| `prove_fault_admit` | **counterexample** | a **single** glitch on admit-enable breaks it |

So the bound is robust to tampering with authentication, and fragile to tampering
with exactly one line. **Your trusted hardware base is the capacity comparator and
the residency counter — not the whole block.** That is an actionable hardening
instruction, not a proof artifact.

The two counterexamples are load-bearing. A verifier that only accepted successes
would hide this.

## 30-second quickstart

```bash
git clone https://github.com/nickharris808/pqc-dos-gate-rtl
cd pqc-dos-gate-rtl
./verify.sh
```

```
  ok    prove_gated              proven (unbounded k-induction)
  ok    prove_fault_gated        proven (unbounded k-induction)
  ok    prove_fault_unbounded    proven (unbounded k-induction)
  ok    prove_naive              counterexample found, as expected
  ok    prove_fault_admit        counterexample found, as expected

All five proofs produced their expected verdict.
```

Needs [Yosys](https://github.com/YosysHQ/yosys) (`brew install yosys`,
`apt install yosys`). No commercial tools, no licences.

## What is proven

Two assertions, checked by temporal k-induction over **all** reachable states —
not simulated, not bounded to a trace length:

```verilog
(S1)  assert (resident <= CAP);              // the bounded-buffer invariant
(S2)  !token_ok -> assert (!admit);          // an unauthenticated fragment is never admitted
```

The admission condition is one line:

```verilog
assign admit = frag_valid & token_ok & (next_sum <= CAP);
```

`next_sum` is computed in a **widened** domain (`WIDTH+1` bits) so the capacity
comparison cannot itself overflow — a 32-bit resident plus a 16-bit fragment
length is a 33-bit sum.

## Synthesis

```bash
cd proofs && yosys synth.ys
```

Reproduces **32 flip-flops** (`$_SDFFE_PP0P_`) for the datapath with formal
assertions excluded — one per bit of the 32-bit residency counter. CI asserts
that number on every push.

**The cell count is version-dependent and is deliberately not claimed as a fixed
figure.** The same script gives 255 cells under Yosys 0.61 and 232 under 0.48,
because the technology-independent mapping changes between releases. An earlier
draft of this README quoted 255 as though it were a property of the design; it is
a property of the design *and* the toolchain. No area figure is quoted either,
since this flow does no liberty mapping.

## Honest scope

**What this proves.** That *this* Verilog module maintains `resident ≤ CAP` and
never admits an unauthenticated fragment, in every reachable state, and that two
specific fault injections do and do not break it.

**What it does NOT prove.**

- **Not that your silicon is safe.** This is one small module. Integrating it,
  and everything around it, is where the risk actually lives.
- **Not a post-synthesis or post-layout result.** The proofs run on RTL. Timing,
  power and physical attacks are out of scope.
- **Not exhaustive fault coverage.** Two fault models were tried. Others exist.
- **Not a repair for the other 38 failure families.** Memory exhaustion is one;
  see [`pqc-mfb`](https://github.com/nickharris808/pqc-mfb).

## Why `verify.sh` asserts verdicts rather than exit codes

Yosys exits 0 whether it proves a property or finds a counterexample — the
verdict is in the output text. So the script asserts the *expected* verdict for
each proof, and two of those expectations are "a counterexample must exist".

It has teeth: deleting the capacity check from the admit condition, or deleting
the token check, each makes `prove_gated` fail. Both mutations were run.

## Related

The same bound, checked three independent ways:

| Where | How |
|---|---|
| **here** | Yosys k-induction on synthesizable RTL |
| [`pqc-bounds-lean`](https://github.com/nickharris808/pqc-bounds-lean) | Lean 4, mathlib-free, 0 `sorry` |
| [`farkas-check`](https://github.com/nickharris808/farkas-check) | 123 lines of integer C, on-device |

[`pqc-sizes`](https://github.com/nickharris808/pqc-sizes) derives the cap ·
[`pqc-dos-embedded`](https://github.com/nickharris808/pqc-dos-embedded) shows the
failure on emulated ARMv7-M

This is one gate. The full post-quantum migration failure surface is a separate
closed codebase, and relevant subject matter is covered by a filed provisional
patent application. For commercial use, open a GitHub Discussion or an issue.

## License

Apache-2.0. See [LICENSE](LICENSE).
