// bounded_reassembly_naive.v — the UNREPAIRED reassemble-then-verify datapath.
//
// The stock design: admit every presented PQC fragment with NO anti-clogging token
// gate and NO bounded-buffer cap, accumulating the whole object before verifying.
// This is the RTL analog of the naive transition in the SMT encoding.
//
// yosys-smtbmc (plain BMC) exhibits a flood trace that VIOLATES `resident <= CAP`:
// under a realistic 512-byte-fragment flood (the per-fragment MTU assumed below,
// matching the embedded FRAG=512 datapoint) the window crosses the 16 KiB cap in
// ~CAP/512 = 32 admits. That counterexample proves the cap in bounded_reassembly.v
// is LOAD-BEARING (the bound genuinely fails without the gate), not a tautology.
//
// Reproduce: `make rtl-gate`.

module bounded_reassembly_naive #(
    parameter integer CAP   = 16384,
    parameter integer WIDTH = 32
) (
    input  wire              clk,
    input  wire              rst,
    input  wire              frag_valid,
    input  wire              token_ok,    // present for interface parity; IGNORED (naive)
    input  wire [15:0]       frag_len,
    input  wire              complete,    // present for interface parity; IGNORED (naive)
    output reg  [WIDTH-1:0]  resident,
    output wire              admit,
    output wire              dropped
);
    // NAIVE: no token gate, no CAP check — admit whatever is presented.
    assign admit   = frag_valid;
    assign dropped = 1'b0;

    always @(posedge clk) begin
        if (rst)        resident <= {WIDTH{1'b0}};
        else if (admit) resident <= resident + {{(WIDTH-16){1'b0}}, frag_len};
    end

`ifdef FORMAL
    always @(posedge clk) begin
        // Assume a realistic per-fragment MTU so the violation is the genuine
        // flood-ACCUMULATION (many small fragments), not a single jumbo fragment.
        assume (frag_len <= 16'd512);
        // The bounded-buffer invariant the gated design upholds — here it FAILS
        // under the flood. yosys SAT returns the counterexample trace.
        assert (resident <= CAP);
    end
`endif
endmodule
