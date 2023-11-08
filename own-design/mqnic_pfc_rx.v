/*

Copyright 2023, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none
 

/*
* Within this module, we have to parse the fields from the frame received from the s_axis_tdata signal
*/
module mqnic_pfc_rx #
(
    parameter PFC_FRAME_SIZE = 512,
    parameter DATA_WIDTH = 256,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    // Propagate tlast signal
    parameter LAST_ENABLE = 1,
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // MAC Control client PFC request data and keep width
    parameter ADDR_WIDTH = 48,
    parameter OPCODE_WIDTH = 16,
    parameter PRIORITY_ENABLE_WIDTH = 16,
    parameter TIME_VECTOR_WIDTH = 128
    // PFC MCF:MA_DATA.request width (see pg. 1408 (771) from 802.3-2018)
    //parameter MCF_DATA_WIDTH = 304,
    // PFC MAC:MA_DATA.request width (see pg. 1408 (771) from 802.3-2018)
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Data input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    // PFC frame from MAC Control client
    input  wire [ADDR_WIDTH-1:0] s_pfc_addr,
    input  wire [OPCODE_WIDTH-1:0] s_pfc_opcode,
    input  wire [PRIORITY_ENABLE_WIDTH-1:0] s_pfc_priority_enable,
    input  wire [TIME_VECTOR_WIDTH-1:0] s_pfc_time_vector,

    /*
     * Data output
     */
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,
    //output wire prueba

    // PFC frame from MAC Control client
    output  wire [ADDR_WIDTH-1:0] m_pfc_addr,
    output  wire [OPCODE_WIDTH-1:0] m_pfc_opcode,
    output  wire [PRIORITY_ENABLE_WIDTH-1:0] m_pfc_priority_enable,
    output  wire [TIME_VECTOR_WIDTH-1:0] m_pfc_time_vector,


    input   wire                      transmit_enable,
    output  wire                      prueba

);

parameter CYCLE_COUNT = (38 + KEEP_WIDTH - 1) / KEEP_WIDTH;
parameter PTR_WIDTH = $clog2(CYCLE_COUNT);

// Transmission states
localparam TRANSMIT_READY = 1;
localparam SEND_CONTROL_FRAME = 2;
localparam SEND_DATA_FRAME = 3;
localparam SEND_FINISH = 4;

// bus width assertions
initial begin
  if (KEEP_WIDTH * 8!= DATA_WIDTH) begin
    $error("Error: AXI stream interface requires byte granularity (instance %m)");
    $finish;
  end
end

assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tid = s_axis_tid;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tuser = s_axis_tuser;

assign m_pfc_addr = s_pfc_addr;
assign m_pfc_opcode = s_pfc_opcode;
assign m_pfc_priority_enable = s_pfc_priority_enable;
assign m_pfc_time_vector = s_pfc_time_vector;

/*
PFC Frame (IPv4)
 Field                       Length
 Destination MAC address     6 octets = 48 bits
 Source MAC address          6 octets = 48 bits
 Ethertype (0x8808)          2 octets = 16 bits
 Opcode (0x0101)             2 octets = 16 bits
 priority_enable_vector      2 octets = 16 bits
 time_vector                 8 x 2 octets = 128 bits
 padding                     26 octets
 FCS
*/

reg                     prueba_reg = 1'b0, prueba_next; // esta es solamente una señal de depuración
reg                     active_reg = 1'b1, active_next;
reg [PTR_WIDTH-1:0]     ptr_reg = 0, ptr_next;
reg [1:0]               state_reg = TRANSMIT_READY, state_next;

// Registers to store the fields of the PFC packet
reg [47:0]    dst_addr_reg = 48'd0, dst_addr_next;
reg [47:0]    src_addr_reg = 48'd0, src_addr_next;
reg [15:0]    pfc_opcode_reg = 16'd0, pfc_opcode_next;
reg [15:0]    eth_type_reg = 16'd0, eth_type_next;
reg [15:0]    priority_enable_vector_reg = 16'd0, priority_enable_vector_next;
reg [127:0]   time_vector_reg = 128'd0, time_vector_next;

// Logic to parse the ethernet frame
always @* begin
  // Registers have to be given a value 
  state_next = state_reg;
  active_next = active_reg;
  ptr_next = ptr_reg;
  prueba_next = prueba_reg;
  dst_addr_next = dst_addr_reg;
  src_addr_next = src_addr_reg;
  pfc_opcode_next = pfc_opcode_reg;
  eth_type_next = eth_type_reg;
  priority_enable_vector_next = priority_enable_vector_reg;
  time_vector_next = time_vector_reg;

  if (s_axis_tvalid) begin
      if(s_pfc_addr == 48'h111111111111) begin
        prueba_next <= 1'b1; 
      end
      else begin
        prueba_next <= 1'b0;
      end
//    if(active_reg) begin
//      ptr_next = ptr_reg + 1;

      // Parse the pfc_opcode
      //if (ptr_reg == 12/MA_CONTROL_KEEP_WIDTH) begin
          // capture destination address
          //pfc_opcode_next = ma_control_request[(12%MA_CONTROL_KEEP_WIDTH)*8 +: 8];
          //if(pfc_opcode_next == 48'h0180C2000001) begin
            //prueba_next = 1'b1;
          //end

//      end
//    end

//    if (s_axis_tlast) begin
//      if (active_next) begin
//        ptr_next = 0;
//        active_next = 1'b1;
//      end
//    end
    /*case(state_reg)
      TRANSMIT_READY: begin
        if (ptr_reg == 0/KEEP_WIDTH) begin
          // capture destination address
          dst_addr_next = s_axis_tdata[(0%KEEP_WIDTH)*8 +: 48];
          src_addr_next = s_axis_tdata[()]
          if(dst_addr_next == 48'h0180C2000001) begin
            prueba_next = 1'b1;
          end

        end
      end
      SEND_CONTROL_FRAME: begin
        
      end
    endcase*/
  end
end


// Registers
//reg [47:0]                  dst_addr_reg;   // Value of 01-80-C2-00-00-01 (pg. 1405)
//reg [PFC_FRAME_SIZE-1:0]    pfc_frame_reg;
//reg                         debug = 0, debug_next;



// PFC operation transmit state diagram (see pg. 1409) 
/*always @(*) begin

  debug_next = 0;
  state_next = state;

  // TODO: parse axis_tdata to extract phys_address;

  if(transmit_enable) begin
    case(state)
      TRANSMIT_READY: begin
        dst_addr_reg <= s_axis_tdata[47:0];
        if(dst_addr_reg == 48'h010000C28001) begin
          state_next = SEND_CONTROL_FRAME;
        end else begin
          state_next = SEND_DATA_FRAME;
        end
      end

      SEND_CONTROL_FRAME: begin
        if(!s_axis_tlast)
        state_next <= SEND_FINISH;
      end

      SEND_DATA_FRAME: begin
        if(!s_axis_tlast) begin
          pfc_frame_reg <= s_axis_tdata;
        end
        else begin
          state_next <= SEND_FINISH;
        end
      end

      SEND_FINISH: begin
        pfc_frame_reg <= s_axis_tdata;
        state_next <= TRANSMIT_READY;
      end
    endcase
  end
end
*/

/*
*  Output logic
*/
always @(posedge clk) begin
  if(rst) begin
    active_reg <= 1'b1;
    ptr_reg <= 0;
    state_reg <= TRANSMIT_READY;
    prueba_reg <= 0;
    dst_addr_reg <= 0;
  end else begin
    active_reg <= active_next;
    ptr_reg <= ptr_next;
    state_reg <= state_next;
    prueba_reg <= prueba_next;
    dst_addr_reg <= dst_addr_next;
  end
end

assign prueba = prueba_reg;

endmodule

`resetall
