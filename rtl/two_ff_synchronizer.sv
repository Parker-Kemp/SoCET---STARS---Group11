module two_ff_synchronizer #(
    parameter int SYNC_STAGES = 2
)(
    input  logic CLK, // Destination clock domain
    input  logic async_in, // Asynchronous input signal
    output logic sync_out // Synchronized output signal
);
    logic [SYNC_STAGES-1:0] sync_reg;

    always_ff @(posedge CLK) begin
        sync_reg <= {sync_reg[SYNC_STAGES-2:0], async_in};
    end

    assign sync_out = sync_reg[SYNC_STAGES-1];

endmodule
