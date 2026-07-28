// bounded_reassembly.v — the marquee PQC memory-DoS gate, carried to RTL.
//
// This is the hardware analog of the bounded-reassembly gate
// fused with the anti-clogging admission gate (mechanisms D / F / N). It is the
// SAME object the Z3 inductive proof reasons about in the SMT encoding
// (the bounded-buffer / anti-clogging law) and the SAME 16 KiB cap measured in
// the reference implementation (cap = 16*1024) and on real ARMv7-M Cortex-M ISA
// (artifacts/native/embedded_dos_ci.json, BOUNDED_CAP = 16 KiB).
//
// The two safety properties proven IN HARDWARE by yosys-smtbmc (k-induction):
//
//   (S1) resident <= CAP          the bounded-buffer invariant. 1-inductive, so it
//                                 holds on EVERY reachable state at ANY depth
//                                 (unbounded) — the line-rate DoS guarantee.
//   (S2) !token_ok => !admit      the anti-clogging gate: an un-authenticated
//                                 fragment is NEVER admitted, so a flood of bogus
//                                 fragments can never grow reassembly state.
//
// The naive counterpart (bounded_reassembly_naive.v) drops the cap+token gate and
// yosys-smtbmc exhibits a flood trace that violates (S1) — so the bound is
// load-bearing, not vacuous (the RTL analog of the z3 "naive_violated" witness).
//
// CAP is a parameter; the comparison is performed in a widened domain so the cap
// check can never wrap. Reproduce: `make rtl-gate`.

module bounded_reassembly #(
    parameter integer CAP   = 16384,   // 16 KiB bounded reassembly window (FLOOD_CAP)
    parameter integer WIDTH = 32       // resident byte-counter width
) (
    input  wire              clk,
    input  wire              rst,        // synchronous reset
    input  wire              frag_valid, // a PQC fragment is presented this cycle
    input  wire              token_ok,   // stateless anti-clogging token verified (the anti-clogging gate)
    input  wire [15:0]       frag_len,   // fragment length in bytes (<= 65535)
    input  wire              complete,   // reassembly finished -> release the window
    output reg  [WIDTH-1:0]  resident,   // bytes currently held in the window
    output wire              admit,       // this fragment is admitted into the window
    output wire              dropped      // this fragment is dropped (gated out)
);
    // Sum in a widened (WIDTH+1) domain so the CAP comparison can never overflow.
    wire [WIDTH:0] next_sum = {1'b0, resident} + {{(WIDTH-15){1'b0}}, frag_len};

    // ADMIT iff (a) a fragment is presented, (b) its anti-clogging token verifies
    // (the anti-clogging gate), and (c) admitting keeps the window within CAP (the capacity gate). The
    // gate is BEFORE any expensive PQC work, so bogus fragments cost only the
    // stateless token check. Otherwise DROP and leave reassembly state unchanged.
    assign admit   = frag_valid & token_ok & (next_sum <= CAP);
    assign dropped = frag_valid & ~admit;

    always @(posedge clk) begin
        if (rst)            resident <= {WIDTH{1'b0}};
        else if (complete)  resident <= {WIDTH{1'b0}};   // release the window on completion
        else if (admit)     resident <= next_sum[WIDTH-1:0];
        // else: hold (dropped or idle) — resident unchanged
    end

`ifdef FORMAL
    always @(posedge clk) begin
        // (S1) the marquee bound: the reassembly window never exceeds CAP — for an
        // ARBITRARY fragment length (no assumption on frag_len). 1-inductive.
        assert (resident <= CAP);

        // (S2) anti-clogging: an un-authenticated fragment is never admitted.
        if (frag_valid && !token_ok)
            assert (!admit);
    end
`endif
endmodule
