// uart_loader.sv
//
// Turns the byte stream from uart_rx into tile count and memory words.
//
// Byte stream for one job:
//   tiles_m, tiles_n, tiles_q        
//   A words: tiles_m * tiles_n * AS  (AS bytes each, value 0 first)
//   B words: tiles_q * tiles_n * AS  (AS bytes each, value 0 first)
//
// Outputs:
//   tiles_x + tiles_x_valid, confirms with a pulse
//   word_data + word_addr, finished word and address in RAM
//   a_word_valid, 1cycle pulse, write word_data into RAM A
//   b_word_valid, 1cycle pulse, write word_data into RAM B
//   start, 1cycle pulse the cycle after the last B word
//

module uart_loader #(
  parameter int AS     = 8,    //array side length (must be 2^n)
  parameter int MT     = 32,    //max tiles per matrix side
  parameter int ADDR_W = $clog2(MT * MT * AS), //RAM address width
  parameter int TILE_W = $clog2(MT + 1)  //hold 1 word, 6 bits bc 1 start 1 stop
) (
  input  logic clk,
  input  logic rst_n,     //active-low reset

  //from uart_rx module
  input  logic [7:0] rx_data,
  input  logic       rx_valid,     //1-cycle pulse per byte

  //tile count
  output logic [TILE_W-1:0] tiles_m, tiles_n, tiles_q,
  output logic              tiles_m_valid, tiles_n_valid, tiles_q_valid,

  //words for RAM A and RAM B
  output logic signed [AS-1:0][7:0] word_data, //value 0 in bits [7:0]
  output logic [ADDR_W-1:0]         word_addr,
  output logic                      a_word_valid,
  output logic                      b_word_valid,

  //ell the compute side to begin
  output logic start
);

  typedef enum logic [2:0] {
    GET_M,  // wait for tiles_m
    GET_N, // wait for tiles_n
    GET_Q,  // wait for tiles_q
    LOAD_A, // collect A words
    LOAD_B, // collect B words
    START  // pulse start, then wait for the next job
  } state_t;

  state_t state;

  logic [$clog2(AS)-1:0] byte_idx;  //which byte of the word comes next
  logic [AS-1:0][7:0]    word_buf;   //bytes collected so far
  logic [AS-1:0][7:0]    next_word;  //word_buf with the incoming byte added
  logic [ADDR_W-1:0]     next_addr;  //address for the word being collected
  logic [ADDR_W-1:0]     last_a_addr; //tiles_m * tiles_n * AS - 1
  logic [ADDR_W-1:0]     last_b_addr; //tiles_q * tiles_n * AS - 1

  
  always_comb begin
    next_word = word_buf;
    next_word[byte_idx] = rx_data;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= GET_M;
      tiles_m       <= '0;
      tiles_n       <= '0;
      tiles_q       <= '0;
      tiles_m_valid <= 1'b0;
      tiles_n_valid <= 1'b0;
      tiles_q_valid <= 1'b0;
      word_data     <= '0;
      word_addr     <= '0;
      a_word_valid  <= 1'b0;
      b_word_valid  <= 1'b0;
      start         <= 1'b0;
      byte_idx      <= '0;
      word_buf      <= '0;
      next_addr     <= '0;
      last_a_addr   <= '0;
      last_b_addr   <= '0;
    end else begin
      tiles_m_valid <= 1'b0;
      tiles_n_valid <= 1'b0;
      tiles_q_valid <= 1'b0;
      a_word_valid  <= 1'b0;
      b_word_valid  <= 1'b0;
      start         <= 1'b0;

      case (state)
        GET_M: if (rx_valid) begin
          tiles_m       <= TILE_W'(rx_data);
          tiles_m_valid <= 1'b1;
          state         <= GET_N;
        end

        GET_N: if (rx_valid) begin
          tiles_n       <= TILE_W'(rx_data);
          tiles_n_valid <= 1'b1;
          state         <= GET_Q;
        end

        GET_Q: if (rx_valid) begin
          tiles_q       <= TILE_W'(rx_data);
          tiles_q_valid <= 1'b1;
          last_a_addr   <= ADDR_W'(tiles_m * tiles_n * AS - 1);
          last_b_addr   <= ADDR_W'(TILE_W'(rx_data) * tiles_n * AS - 1);
          byte_idx      <= '0;
          next_addr     <= '0;
          state         <= LOAD_A;
        end

        LOAD_A, LOAD_B: if (rx_valid) begin
          if (byte_idx == $clog2(AS)'(AS - 1)) begin
            byte_idx  <= '0;
            word_data <= next_word;
            word_addr <= next_addr;
            if (state == LOAD_A) begin
              a_word_valid <= 1'b1;
              if (next_addr == last_a_addr) begin
                next_addr <= '0;
                state     <= LOAD_B;
              end else begin
                next_addr <= next_addr + 1'b1;
              end
            end else begin
              b_word_valid <= 1'b1;
              if (next_addr == last_b_addr) begin
                next_addr <= '0;
                state     <= START;       
              end else begin
                next_addr <= next_addr + 1'b1;
              end
            end
          end else begin
            word_buf <= next_word;          
            byte_idx <= byte_idx + 1'b1;
          end
        end

        START: begin
          start <= 1'b1;
          state <= GET_M;
        end

        default: state <= GET_M;
      endcase
    end
  end

endmodule
