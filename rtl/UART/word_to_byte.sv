// word_to_byte.sv
//
// Sends one C word (AS signed INT32 values) to uart_tx as AS * 4 bytes.
// Order: value 0 first, and each value is sent LSB
//
//   in:  a word is taken on a cycle where cword_valid and cword_ready are both 1
//   out: a byte is taken on a cycle where tx_valid and tx_ready are both 1

module word_to_byte #(
  parameter int AS = 8            //vaues per C word
) (
  input  logic clk,
  input  logic rst_n,              //active-low reset

  //word in from RAM C
  input  logic signed [AS-1:0][31:0] cword,     //value 0 in bits [31:0]
  input  logic                       cword_valid,
  output logic                       cword_ready, //idle, can take a new word

  //bytes out to tx hardware mod
  output logic [7:0] tx_data,
  output logic       tx_valid,
  input  logic       tx_ready
);

  localparam int NUM_BYTES = AS * 4;   //32 bytes for AS = 8
  localparam int IDX_W     = $clog2(NUM_BYTES);

  logic [AS*32-1:0] word_reg;          //the word being sent
  logic [IDX_W-1:0] byte_idx;          //which byte is on tx_data
  logic             busy;              //high when sending a word (busy)

  assign cword_ready = !busy;
  assign tx_valid    = busy;
  assign tx_data     = word_reg[byte_idx * 8 +: 8];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      word_reg <= '0;
      byte_idx <= '0;
      busy     <= 1'b0;
    end else if (!busy) begin
      if (cword_valid) begin       //takes a new word
        word_reg <= cword;
        byte_idx <= '0;
        busy     <= 1'b1;
      end
    end else if (tx_ready) begin          //uart_tx took the current byte
      if (byte_idx == IDX_W'(NUM_BYTES - 1)) begin
        busy <= 1'b0;              //whole word sent
      end else begin
        byte_idx <= byte_idx + 1'b1;
      end
    end
  end

endmodule
