//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Artem Kozhevnikov
//
// Module Name: apb_timer
// Client Project: course_job_v12
// Dependencies:
//
// Revision: 30.05.24
// Additional Comments: timer works with APB interface as a slave.
//
//////////////////////////////////////////////////////////////////////////////////

module apb_timer (
  input          pclk,
  input          preset_n,  // Active low reset   
  input          psel_o,
  input          penable_o,
  input   [31:0] paddr_o,
  input          pwrite_o,
  input   [7:0]  pwdata_o,
  output  [7:0]  prdata_i,
  output         pready_i,
  output         timeout
);
  //reg is_set; // to start listening for start/stop instructions
  reg [7:0] counter; // for timer
  reg start_stop; // start <=> 1; stop <=> 0
  reg pready_ii; // inner reg for pready_i
  reg [7:0] prdata_ii; // inner reg for predata_i
  reg is_timeout; // inner reg for timeout

  always @(posedge pclk or negedge preset_n) begin
    if (~preset_n) begin
      pready_ii <= 1'b0;
      start_stop <= 1'b0;
      counter <= 8'b0;
      //is_set <= 1'b0;
      is_timeout <= 1'b0;
    end else begin
      if (start_stop && counter > 8'b0) counter <= (counter - 1'b1); // count
      else if(counter == 8'b0 && start_stop == 1'b1) is_timeout <= 1'b1; // send 1 when completed
      
      if (psel_o && penable_o) begin // ACCESS
        pready_ii <= 1'b1;
        if (pwrite_o) begin  // if WRITE
          if(paddr_o == 32'hA000) begin
            counter <= pwdata_o;
            //is_set <= 1'b1;
          end else if(paddr_o == 32'hA001)
            start_stop <= pwdata_o;
        end else begin  // if READ
          prdata_ii <= counter;
        end
      end else begin
        pready_ii <= 1'b0;
      end
    end
  end
  assign pready_i = pready_ii;
  assign prdata_i = prdata_ii;
  assign timeout = is_timeout;

endmodule
