// bounded_reassembly_fault_admit.v — the DUAL fault (v38-FI teeth).  Here the
// single-event-upset fault targets the ADMIT ENABLE directly (forces admit high
// for one cycle, bypassing the CAP comparator).  Unlike a token-bypass fault, this
// DOES break the bound: yosys-smtbmc BMC (prove_fault_admit.ys) exhibits a trace in
// which one glitched admit pushes resident past CAP.  This makes the fault analysis
// non-vacuous and pinpoints the hardware trusted-computing-base for the DoS bound:
// the CAP comparator and the resident counter must be hardened (TMR/ECC); a fault
// anywhere else (e.g. the token gate) cannot violate (S1).

module bounded_reassembly_fault_admit #(
    parameter integer CAP   = 16384,
    parameter integer WIDTH = 32
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              frag_valid,
    input  wire              token_ok,
    input  wire [15:0]       frag_len,
    input  wire              complete,
    input  wire              admit_glitch, // adversary requests an admit-enable fault
    output reg  [WIDTH-1:0]  resident,
    output wire              admit,
    output wire              dropped
);
    reg fault_used;
    wire glitch_fire = admit_glitch & ~fault_used;
    always @(posedge clk) begin
        if (rst)              fault_used <= 1'b0;
        else if (glitch_fire) fault_used <= 1'b1;
    end

    wire [WIDTH:0] next_sum = {1'b0, resident} + {{(WIDTH-15){1'b0}}, frag_len};
    wire admit_gated = frag_valid & token_ok & (next_sum <= CAP);

    // The fault bypasses the CAP comparator — this is the TCB signal.
    assign admit   = admit_gated | glitch_fire;
    assign dropped = frag_valid & ~admit;

    always @(posedge clk) begin
        if (rst)            resident <= {WIDTH{1'b0}};
        else if (complete)  resident <= {WIDTH{1'b0}};
        else if (admit)     resident <= next_sum[WIDTH-1:0];
    end

`ifdef FORMAL
    always @(posedge clk) begin
        // (S1) — BMC will FIND a single-fault trace that violates this, proving the
        // admit-enable / comparator is the trusted computing base.
        assert (resident <= CAP);
    end
`endif
endmodule
