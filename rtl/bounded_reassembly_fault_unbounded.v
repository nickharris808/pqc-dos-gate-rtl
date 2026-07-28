// bounded_reassembly_fault_unbounded.v — the STRONGER token-fault result (v38-FI).
// bounded_reassembly_fault.v proves `resident <= CAP` survives a SINGLE token-bypass
// glitch (SEU budget = 1). This module proves the same bound survives an UNBOUNDED
// number of token-bypass glitches: the adversary may force the anti-clogging token
// check high on EVERY cycle (token_eff is unconditionally driven by tok_glitch, with
// NO fault budget). k-induction still proves `resident <= CAP` for all reachable
// states — because the CAP admission comparator (next_sum <= CAP) is independent of
// the token gate, so no amount of token faulting can violate the memory bound. This
// is strictly stronger than the single-fault result and pins the guarantee entirely
// on the counter+comparator, not on limiting the attacker's fault count.

module bounded_reassembly_fault_unbounded #(
    parameter integer CAP   = 16384,
    parameter integer WIDTH = 32
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              frag_valid,
    input  wire              token_ok,
    input  wire [15:0]       frag_len,
    input  wire              complete,
    input  wire              tok_glitch,   // UNBOUNDED: may fire on any/every cycle
    output reg  [WIDTH-1:0]  resident,
    output wire              admit,
    output wire              dropped
);
    // NO fault budget: the token check may be bypassed on every cycle.
    wire token_eff = token_ok | tok_glitch;

    wire [WIDTH:0] next_sum = {1'b0, resident} + {{(WIDTH-15){1'b0}}, frag_len};

    // The CAP admission check is INDEPENDENT of the token, so (S1) survives even
    // under unbounded token faulting.
    assign admit   = frag_valid & token_eff & (next_sum <= CAP);
    assign dropped = frag_valid & ~admit;

    always @(posedge clk) begin
        if (rst)            resident <= {WIDTH{1'b0}};
        else if (complete)  resident <= {WIDTH{1'b0}};
        else if (admit)     resident <= next_sum[WIDTH-1:0];
    end

`ifdef FORMAL
    always @(posedge clk) begin
        // (S1) holds even when token_eff is faulted high on every cycle.
        assert (resident <= CAP);
    end
`endif
endmodule
