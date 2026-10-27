// uart_rx.sv
// UART receiver: 8 data bits, no parity, 1 stop bit (8N1), receiving LSB
//
// The serial line idles high. Each byte is a start bit (0), 8 data bits
// sent least significant bit first, and a stop bit (1). The receiver finds
// the middle of the start bit, then samples every full bit period so each
// sample lands in the middle of a bit, where the signal is most stable.

module uart_rx #(
  parameter int CLK_FREQ = 100_000_000,  //  clock frequency in Hz
  parameter int BAUD     = 115_200       // baud rate; must match the PC side
) (
  input  logic       clk,          //self explanatory
  input  logic       rst_n,        // active-low reset
  input  logic       rx,           // serial line
  output logic [7:0] data_out,     // most recently received byte
  output logic       data_valid,   // 1-cycle pulse: a good byte is on data_out
  output logic       frame_error   // 1-cycle pulse: stop bit was 0, byte dropped
);

  // Clock cycles per bit, rounded to the nearest int
  localparam int CLKS_PER_BIT = (CLK_FREQ + BAUD / 2) / BAUD;
  localparam int HALF_BIT     = CLKS_PER_BIT / 2;
  localparam int CW           = $clog2(CLKS_PER_BIT);

  // Two-flip-flop synchronizer. rx is not related to our clock, prevents metastability
  logic rx_meta, rx_sync;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
    end else begin
      rx_meta <= rx;
      rx_sync <= rx_meta;
    end
  end

  // Receive state machine
  typedef enum logic [1:0] {
    IDLE,   // waiting for the line to drop (start of a start bit) UART
    START,  // waiting until the middle of the start bit to confirm it
    DATA,   // sampling the 8 data bits
    STOP    // sampling the stop bit
  } state_t;

  state_t        state;
  logic [CW-1:0] clk_cnt;    // counts clock cycles within a bit
  logic [2:0]    bit_idx;    // which data bit is being received (0-7)
  logic [7:0]    shift_reg;  // data bits collected so far

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      clk_cnt     <= '0;
      bit_idx     <= '0;
      shift_reg   <= '0;
      data_out    <= '0;
      data_valid  <= 1'b0;
      frame_error <= 1'b0;
    end else begin
      // Pulse outputs default to 0 and are raised for one cycle below.
      data_valid  <= 1'b0;
      frame_error <= 1'b0;

      case (state)
        IDLE: begin
          clk_cnt <= '0;
          bit_idx <= '0;
          if (!rx_sync) state <= START;  // line dropped: possible start bit
        end

        START: begin
          if (clk_cnt == CW'(HALF_BIT - 1)) begin
            clk_cnt <= '0;
            state <= rx_sync ? IDLE : DATA;
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        DATA: begin
          if (clk_cnt == CW'(CLKS_PER_BIT - 1)) begin
            clk_cnt            <= '0;
            shift_reg[bit_idx] <= rx_sync;  // LSB arrives first
            if (bit_idx == 3'd7) state   <= STOP;
            else                 bit_idx <= bit_idx + 1'b1;
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        STOP: begin
          if (clk_cnt == CW'(CLKS_PER_BIT - 1)) begin
            clk_cnt <= '0;
            if (rx_sync) begin
              data_out   <= shift_reg;  // valid stop bit
              data_valid <= 1'b1;
            end else begin
              frame_error <= 1'b1;      // detects corrupted byte if the stop bit is 0
            end
            // Return to IDLE in the middle of the stop bit, to get back on track
            state <= IDLE;
          end else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
