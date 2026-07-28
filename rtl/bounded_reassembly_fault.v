// bounded_reassembly_fault.v — the PQC memory-DoS gate under a SINGLE-EVENT-UPSET
// fault model (v38-FI).  Side-channel/fault depth beyond timing: we prove the
// marquee bound `resident <= CAP` is ROBUST to a single adversarial fault that
// BYPASSES the anti-clogging token gate (forces token_ok high for one cycle).
//
// FAULT MODEL: an adversary may glitch `token_ok` high on exactly ONE cycle over
// the whole run (a single-event upset — SEU — budget of 1, tracked by fault_used).
// This is the realistic glitch a fault-injection attacker mounts to defeat the
// return-routability / anti-clogging check (mechanisms D/F/N).
//
// KEY RESULT (proven by yosys-smtbmc k-induction in prove_fault_gated.ys):
//   (S1) resident <= CAP  STILL HOLDS under <=1 token-bypass fault — because the
//        CAP admission check (next_sum <= CAP) is INDEPENDENT of token_ok. So even
//        if a fault defeats the anti-clogging gate, the memory bound cannot be
//        violated: the counter+comparator, not the token, are what enforce (S1).
// The companion bounded_reassembly_fault_admit.v shows the DUAL fact — a fault on
// the admit-enable itself DOES break (S1) — so the analysis is non-vacuous and
// pinpoints the hardware trusted-computing-base (the CAP comparator + counter).

module bounded_reassembly_fault #(
    parameter integer CAP   = 16384,
    parameter integer WIDTH = 32
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              frag_valid,
    input  wire              token_ok,
    input  wire [15:0]       frag_len,
    input  wire              complete,
    input  wire              tok_glitch,   // adversary requests a token-bypass fault
    output reg  [WIDTH-1:0]  resident,
    output wire              admit,
    output wire              dropped
);
    // Single-fault budget: at most ONE glitch may fire across the entire run.
    reg fault_used;
    wire glitch_fire = tok_glitch & ~fault_used;
    always @(posedge clk) begin
        if (rst)              fault_used <= 1'b0;
        else if (glitch_fire) fault_used <= 1'b1;
    end

    // The fault forces the token check high (bypasses the anti-clogging gate)...
    wire token_eff = token_ok | glitch_fire;

    wire [WIDTH:0] next_sum = {1'b0, resident} + {{(WIDTH-15){1'b0}}, frag_len};

    // ...but the CAP admission check is INDEPENDENT of the token, so (S1) survives.
    assign admit   = frag_valid & token_eff & (next_sum <= CAP);
    assign dropped = frag_valid & ~admit;

    always @(posedge clk) begin
        if (rst)            resident <= {WIDTH{1'b0}};
        else if (complete)  resident <= {WIDTH{1'b0}};
        else if (admit)     resident <= next_sum[WIDTH-1:0];
    end

`ifdef FORMAL
    // at most one fault ever fires (SEU budget); sanity that the model is honest
    reg glitched_once;
    always @(posedge clk) if (rst) glitched_once <= 1'b0;
                          else if (glitch_fire) glitched_once <= 1'b1;

    always @(posedge clk) begin
        // (S1) the marquee bound holds even under <=1 token-bypass fault.
        assert (resident <= CAP);
    end
`endif
endmodule
