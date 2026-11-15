// uart_rx.sv
// UART receiver: 8 data bits, no parity bit, 1 stop bit, sent LSB
//
// Each byte is a start bit (low), 8 bits are sent LSB, then theres a stop bit (high).
// Receiver finds middle of start bit, then it samples every full bit where its most stable

module uart_rx #(
  parameter int CLK_FREQ = 50000000,   //clock freq (Hz) (DE2-115 board clock is 50 MHz)
  parameter int BAUD     = 115200       //baud rate, must match python script
) (
  input  logic       clk,          //self explanatory
  input  logic       rst_n,        //active-low reset
  input  logic       rx,           //serial line
  output logic [7:0] data_out,     //most recently received byte
  output logic       data_valid,   //1-cycle pulse, a good byte is on data_out
  output logic       frame_error   //1-cycle pulse, stop bit was 0, byte dropped
);

  //Clock cycles per bit, rounded to the nearest int val
  localparam int CLKS_PER_BIT = (CLK_FREQ + BAUD / 2) / (BAUD);
  localparam int HALF_BIT     = CLKS_PER_BIT / 2;
  localparam int CW           = $clog2(CLKS_PER_BIT);

  //Two flip-flop sync to prevent metastability
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

  //FSM setup
  typedef enum logic [1:0] {
    IDLE,   //Waits for start bit, low signal
    START,  //Waits for middle of start bit
    DATA,   //samples the 8 data bits
    STOP    //samples the stop bit
  } state_t;

  state_t        state;
  logic [CW-1:0] clk_cnt;    //counts clock cycles within a bit
  logic [2:0]    bit_idx;    //tracks which data bit is being received (0-7)
  logic [7:0]    shift_reg;  //stores data bits collected so far

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
      data_valid  <= 1'b0;
      frame_error <= 1'b0;

      case (state)
        IDLE: begin
          clk_cnt <= '0;
          bit_idx <= '0;
          if (!rx_sync) state <= START;  //Signal drops, could be a start bit
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
            shift_reg[bit_idx] <= rx_sync; //LSB
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
              data_out   <= shift_reg; //detects valid stop bit
              data_valid <= 1'b1;
            end else begin
              frame_error <= 1'b1; //detects corrupted byte if the stop bit is 0, not 1
            end
            //Returns to IDLE in the middle of the stop bit, gets back on track
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
