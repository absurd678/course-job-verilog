`include "slave_timer.v"
`define CLK @(posedge pclk)

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Artem Kozhevnikov
//
// Create Date: 01.05.2024 
// Module Name: apb_master_tb
// Project Name: course_job_v12
// Revision: 30.05.2024
// Additional Comments: master initiates transactions inside this testbench.
//
//////////////////////////////////////////////////////////////////////////////////


module apb_master_tb ();
  // I/O
  reg           pclk;
  reg           preset_n;   // Active low reset
  reg  [1:0]    add_i;      // 2'b00 - NOP, 2'b01 - READ, 2'b11 - WRITE - NOT IO!!!
  wire          psel_o;
  wire          penable_o;
  wire [31:0]   paddr_o;
  wire          pwrite_o;
  wire  [7:0]   pwdata_o; // input to slave
  wire  [7:0]   prdata_i;
  wire          pready_i;
  wire          is_timeout;

  // inner registers
  reg [1:0] state_q, nxt_state;
  wire apb_state_setup, apb_state_access;
  reg nxt_pwrite, pwrite_q;
  reg [7:0] nxt_rdata, rdata_q;
  reg [7:0] pwdata_int; // inner register for pwdata_o
  reg [31:0]   paddr_inside; // for paddr_o
  
  // Implement clock
  always begin
    pclk = 1'b0;
    #5;
    pclk = 1'b1;
    #5;
  end

  // Instantiate the RTL
  apb_timer APB_SLAVE (
    .pclk(pclk),
    .preset_n(preset_n),
    .psel_o(psel_o),
    .penable_o(penable_o),
    .paddr_o(paddr_o),
    .pwrite_o(pwrite_o),
    .pwdata_o(pwdata_o),
    .prdata_i(prdata_i),
    .pready_i(pready_i),
    .timeout(timeout)
  );

  // Drive stimulus
  initial begin
    preset_n = 1'b0;
    pwdata_int = 8'b0;
    add_i = 2'b00;
    repeat (2) @(posedge pclk);
    preset_n = 1'b1;
    repeat (2) @(posedge pclk);

// 1st test - set, start, stop the timer
    // set timer
    pwdata_int = 8'b11001000; // 200 stimulses
    paddr_inside = 32'hA000;
    add_i = 2'b11;
    repeat (2) @(posedge pclk);
    add_i = 2'b00;
    repeat (2) @(posedge pclk);

    //start timer
    pwdata_int = 1'b1;
    paddr_inside = 32'hA001;
    add_i = 2'b11;
    repeat (2) @(posedge pclk);
    add_i = 2'b00;
    repeat (50) @(posedge pclk);

    // Stop timer
    pwdata_int = 1'b0;
    add_i = 2'b11;
    repeat (2) @(posedge pclk);
    add_i = 2'b00;
    repeat (4) `CLK;

    // Read
    add_i = 2'b01;
    repeat (2) @(posedge pclk);
    add_i = 2'b00;
    repeat (4) @(posedge pclk);

// 2nd test - start, wait
    //start timer, wait
    pwdata_int = 1'b1;
    add_i = 2'b11;
    repeat (2) @(posedge pclk);
    add_i = 2'b00;
    repeat (200) @(posedge pclk);
    $finish();
  end


  always @(posedge pclk or negedge preset_n)
  begin
    if (~preset_n) begin
      state_q <= 2'b00;
    end else begin
      state_q <= nxt_state;
    end
  end

  always @*
  begin
    nxt_pwrite = pwrite_q;
    nxt_rdata = rdata_q;
    nxt_state = state_q;
    case (state_q)
      2'b00:  // IDLE
        if (add_i[0]) begin
          nxt_state = 2'b01;
          nxt_pwrite = add_i[1];
        end
      2'b01: nxt_state = 2'b10;  // SETUP
      2'b10: // ACCESS
        if (pready_i) begin
          if (~pwrite_q)
            nxt_rdata = prdata_i;
          nxt_state = 2'b00;
        end
    endcase
  end
  
  assign apb_state_access = (state_q == 2'b10);
  assign apb_state_setup = (state_q == 2'b01);
  
  assign psel_o = apb_state_setup | apb_state_access;
  assign penable_o = apb_state_access;
  
  // APB Address
  assign paddr_o = paddr_inside;
  
  // APB PWRITE control signal
  always @(posedge pclk or negedge preset_n)
    if (~preset_n)
      pwrite_q <= 1'b0;
    else
      pwrite_q <= nxt_pwrite;
  
  assign pwrite_o = pwrite_q;
  assign pwdata_o = pwdata_int;

  always @(posedge pclk or negedge preset_n)
    if (~preset_n)
      rdata_q <= 8'b0;
    else
      rdata_q <= nxt_rdata;


  // VCD Dump
  initial begin
    $dumpfile("apb_master.vcd");
    $dumpvars(2, apb_master_tb);
  end

endmodule
