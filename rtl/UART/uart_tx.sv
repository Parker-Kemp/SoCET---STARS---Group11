// uart_tx.sv
// UART transmitter: 8 data bits, no parity, 1 stop bit (8N1)
//
// Sends each byte as a start bit (0), 8 data bits least significant bit
// first, and a stop bit (1). The line idles high.
//
// Uses a ready/valid handshake: a byte is accepted on any clock cycle where
// tx_valid and tx_ready are both 1. tx_ready stays low while the byte is
// being sent, then returns high when the transmitter can take another.

module uart_tx #(
  parameter int CLK_FREQ = 100000000,  // Hz for clock freq (100m)
  parameter int BAUD     = 115200       // baud rate; must match the python script and rx (115,200)
) (
  input  logic       clk,
  input  logic       rst_n,      // active-low reset
  input  logic [7:0] data_in,    // byte to send
  input  logic       tx_valid,   // sender has a byte on data_in
  output logic       tx_ready,   // transmitter is idle and can take a byte
  output logic       tx          // serial line to the PC
);

  // Clock cycles per bit, rounded to the nearest int
  localparam int CLKS_PER_BIT = (CLK_FREQ + BAUD / 2) / BAUD;
  localparam int CW           = $clog2(CLKS_PER_BIT);

  typedef enum logic [1:0] {
    IDLE,   // line high, wai for a byte
    START,  // sending the start bit
    DATA,   // sending the 8 data bits
    STOP    // sending the stop bit
  } state_t;

  state_t        state;
  logic [CW-1:0] clk_cnt;    // counts clock cycles within a bit
  logic [2:0]    bit_idx;    // which data bit is being sent (0-7)
  logic [7:0]    shift_reg;  // byte being sent; shifts right each bit

  // Ready only while idle. The find start bit happens in the IDLE state below.
  assign tx_ready = (state == IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      clk_cnt   <= '0;
      bit_idx   <= '0;
      shift_reg <= '0;
      tx        <= 1'b1;  // must idle high, or the PC sees a false start bit
    end else begin
      case (state)
        IDLE: begin
          tx      <= 1'b1;
          clk_cnt <= '0;
          bit_idx <= '0;
          if (tx_valid) begin       // tx_ready is 1 in IDLE, start bit detected
            shift_reg <= data_in;   // capture the byte
            tx        <= 1'b0;      // start bit
            state     <= START;
          end
        end

        START: begin
          if (clk_cnt == CW'(CLKS_PER_BIT - 1)) begin
            clk_cnt <= '0;
            tx      <= shift_reg[0];  // first nonstart bit (LSB order)
            state   <= DATA;
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        DATA: begin
          if (clk_cnt == CW'(CLKS_PER_BIT - 1)) begin
            clk_cnt <= '0;
            if (bit_idx == 3'd7) begin
              tx    <= 1'b1;            // all 8 bits sent, begin the stop bit, no parity
              state <= STOP;
            end else begin
              bit_idx   <= bit_idx + 1'b1;
              shift_reg <= {1'b0, shift_reg[7:1]};
              tx        <= shift_reg[1];  // next bit
            end
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        STOP: begin
          if (clk_cnt == CW'(CLKS_PER_BIT - 1)) begin
            clk_cnt <= '0;
            state   <= IDLE;  // tx stays high for next byte
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
