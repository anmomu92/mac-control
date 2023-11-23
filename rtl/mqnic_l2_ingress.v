// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC layer 2 ingress processing
 */
module mqnic_l2_ingress #
(
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 256,

    // AXI keep enable signal
    //parameter AXIS_KEEP_ENABLE = AXIS_DATA_WIDTH>8,

    // AXI stream tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tuser signal width
    parameter USER_WIDTH = 1,
    // Can apply backpressure with tready
    parameter USE_READY = 0,

    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    // parameter USER_WIDTH = 1,
    // parameter USE_READY = 0,
    // parameter MCF_PARAMS_SIZE = 18

    // MAC control
    parameter MCF_PARAMS_SIZE = 18
    //parameter PFC_ENABLE = 1
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * Receive data input (DATA COMES FROM OUTSIDE)
     */
    input  wire [DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]       s_axis_tkeep,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tlast,
    input  wire [USER_WIDTH-1:0]       s_axis_tuser,

    input  wire [ID_WIDTH-1:0]           s_axis_tid,
    input  wire [DEST_WIDTH-1:0]         s_axis_tdest,


    /*
     * Receive data output (DATA IS SENT TO INTERNAL DATAPATH)
     */
    output wire [DATA_WIDTH-1:0]       m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]       m_axis_tkeep,
    output wire                             m_axis_tvalid,
    input  wire                             m_axis_tready,
    output wire                             m_axis_tlast,
    output wire [USER_WIDTH-1:0]       m_axis_tuser,

    output wire [ID_WIDTH-1:0]           m_axis_tid,
    output wire [DEST_WIDTH-1:0]         m_axis_tdest,

    /*
     * MAC control frame interface
     */
    output wire                          mcf_valid,
    output wire [47:0]                   mcf_eth_dst,
    output wire [47:0]                   mcf_eth_src,
    output wire [15:0]                   mcf_eth_type,
    output wire [15:0]                   mcf_opcode,
    output wire [MCF_PARAMS_SIZE*8-1:0]  mcf_params,
    output wire [ID_WIDTH-1:0]           mcf_id,
    output wire [DEST_WIDTH-1:0]         mcf_dest,
    output wire [USER_WIDTH-1:0]         mcf_user,

    /*
     * MAC control frame configuration
     */
    input  wire [47:0]                   cfg_mcf_rx_eth_dst_mcast,
    input  wire                          cfg_mcf_rx_check_eth_dst_mcast,
    input  wire [47:0]                   cfg_mcf_rx_eth_dst_ucast,
    input  wire                          cfg_mcf_rx_check_eth_dst_ucast,
    input  wire [47:0]                   cfg_mcf_rx_eth_src,
    input  wire                          cfg_mcf_rx_check_eth_src,
    input  wire [15:0]                   cfg_mcf_rx_eth_type,
    input  wire [15:0]                   cfg_mcf_rx_opcode_lfc,
    input  wire                          cfg_mcf_rx_check_opcode_lfc,
    input  wire [15:0]                   cfg_mcf_rx_opcode_pfc,
    input  wire                          cfg_mcf_rx_check_opcode_pfc,
    input  wire                          cfg_mcf_rx_forward,
    input  wire                          cfg_mcf_rx_enable,

     /*
     * MAC control frame status
     */
    output wire                          stat_rx_mcf
);

// placeholder
assign m_axis_tdata = int_axis_tdata;
assign m_axis_tkeep = int_axis_tkeep;
assign m_axis_tvalid = int_axis_tvalid;
assign s_axis_tready = int_axis_tready;
assign m_axis_tlast = int_axis_tlast;
assign m_axis_tuser = int_axis_tuser;

assign m_axis_tid = int_axis_tid;
assign m_axis_tdest = int_axis_tdest;

assign mcf_valid = int_mcf_valid;
assign mcf_eth_dst = int_mcf_eth_dst;
assign mcf_eth_src = int_mcf_eth_src;
assign mcf_eth_type = int_mcf_eth_type;
assign mcf_opcode = int_mcf_opcode;
assign mcf_params = int_mcf_params;
assign mcf_id = int_mcf_id;
assign mcf_dest = int_mcf_dest;
assign mcf_user = int_mcf_user;

// registers
reg [DATA_WIDTH-1:0]  int_axis_tdata;
reg [KEEP_WIDTH-1:0]  int_axis_tkeep;
reg                        int_axis_tvalid;
reg                        int_axis_tready;
reg                        int_axis_tlast;
reg [USER_WIDTH-1:0]  int_axis_tuser;
reg [ID_WIDTH-1:0]         int_axis_tid;
reg [DEST_WIDTH-1:0]       int_axis_tdest;

wire                          int_mcf_valid;
wire [47:0]                   int_mcf_eth_dst = 0;
wire [47:0]                   int_mcf_eth_src = 0;
wire [15:0]                   int_mcf_eth_type = 0;
wire [15:0]                   int_mcf_opcode = 0;
wire [MCF_PARAMS_SIZE*8-1:0]  int_mcf_params = 0;
wire [ID_WIDTH-1:0]           int_mcf_id = 0;
wire [DEST_WIDTH-1:0]         int_mcf_dest = 0;
wire [USER_WIDTH-1:0]         int_mcf_user = 0;

wire int_stat_tx_mcf;
/*
This module manages the reception of MAC control frames.  Incoming frames are
checked based on the ethertype and (optionally) MAC addresses.  Matching control
frames are marked by setting tuser[0] on the data output and forwarded through
a separate interface for processing.

It parses the MAC control frame from the AXI stream and sends it through the mcf interface. 
At this point, we don't know if the MAC control frame belongs to lfc or pfc.
*/
mac_ctrl_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .KEEP_ENABLE(DATA_WIDTH>8),
    .KEEP_WIDTH(KEEP_WIDTH),
    .ID_ENABLE(ID_ENABLE),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(DEST_ENABLE),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .USE_READY(USE_READY),
    .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
) mac_ctrl_rx_inst(
    .clk(clk),
    .rst(rst),

    /*
     * AXI stream input
     */
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(int_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tid(s_axis_tid),
    .s_axis_tdest(s_axis_tdest),
    .s_axis_tuser(s_axis_tuser),

    /*
     * AXI stream output
     */
    .m_axis_tdata(int_axis_tdata),
    .m_axis_tkeep(int_axis_tkeep),
    .m_axis_tvalid(int_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(int_axis_tlast),
    .m_axis_tid(int_axis_tid),
    .m_axis_tdest(int_axis_tdest),
    .m_axis_tuser(int_axis_tuser),

    /*
     * MAC control frame interface
     */
    .mcf_valid(int_mcf_valid),
    .mcf_eth_dst(int_mcf_eth_dst),
    .mcf_eth_src(int_mcf_eth_src),
    .mcf_eth_type(int_mcf_eth_type),
    .mcf_opcode(int_mcf_opcode),
    .mcf_params(int_mcf_params),
    .mcf_id(int_mcf_id),
    .mcf_dest(int_mcf_dest),
    .mcf_user(int_mcf_user),

    /*
     * MAC control frame configuration
     */
    .cfg_mcf_rx_eth_dst_mcast(cfg_mcf_rx_eth_dst_mcast),
    .cfg_mcf_rx_check_eth_dst_mcast(cfg_mcf_rx_check_eth_dst_mcast),
    .cfg_mcf_rx_eth_dst_ucast(cfg_mcf_rx_eth_dst_ucast),
    .cfg_mcf_rx_check_eth_dst_ucast(cfg_mcf_rx_check_eth_dst_ucast),
    .cfg_mcf_rx_eth_src(cfg_mcf_rx_eth_src),
    .cfg_mcf_rx_check_eth_src(cfg_mcf_rx_check_eth_src),
    .cfg_mcf_rx_eth_type(cfg_mcf_rx_eth_type),
    .cfg_mcf_rx_opcode_lfc(cfg_mcf_rx_opcode_lfc),
    .cfg_mcf_rx_check_opcode_lfc(cfg_mcf_rx_check_opcode_lfc),
    .cfg_mcf_rx_opcode_pfc(cfg_mcf_rx_opcode_pfc),
    .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc),
    .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
    .cfg_mcf_rx_enable(cfg_mcf_rx_enable),

    /*
     * MAC control frame status
     */
    .stat_rx_mcf(stat_rx_mcf)

);

initial begin
  $monitor("TOP MODULE. Time = %0t: ", $time,
  "\n\t Value of int_axis_tdata is %h, int_axis_tkeep %h, int_axis_tvalid %h, int_axis_tready %h, int_axis_tlast %h, int_axis_tuser %h, int_axis_tid %h",
  int_axis_tdata, int_axis_tkeep, int_axis_tvalid, int_axis_tready, int_axis_tlast, int_axis_tuser, int_axis_tid,
  "\n\t Value of s_tdata is %h, s_tkeep %h, s_tvalid %h, s_tready %h, s_tlast %h, s_tuser %h, s_tid %h", 
  s_axis_tdata, s_axis_tkeep, s_axis_tvalid, s_axis_tready, s_axis_tlast, s_axis_tuser, s_axis_tid,
  "\n\t Value of m_tdata is %h, m_tkeep %h, m_tvalid %h, m_tready %h, m_tlast %h, m_tuser %h, m_tid %h", 
  m_axis_tdata, m_axis_tkeep, m_axis_tvalid, m_axis_tready, m_axis_tlast, m_axis_tuser, m_axis_tid,
  "\n\t Value of mcf_valid is %h, mcf_eth_dst %h, mcf_eth_src %h, mcf_eth_type %h, mcf_opcode %h, mcf_params %h, mcf_id %h, mcf_dest %h, mcf_user %h", 
  mcf_valid, mcf_eth_dst, mcf_eth_src, mcf_eth_type, mcf_opcode, mcf_params, mcf_id, mcf_dest, mcf_user,
  "\n\t Value of int_mcf_valid is %h, int_mcf_eth_dst %h, int_mcf_eth_src %h, int_mcf_eth_type %h, int_mcf_opcode %h, int_mcf_params %h, int_mcf_id %h, int_mcf_dest %h, int_mcf_user %h", 
  int_mcf_valid, int_mcf_eth_dst, int_mcf_eth_src, int_mcf_eth_type, int_mcf_opcode, int_mcf_params, int_mcf_id, int_mcf_dest, int_mcf_user);
end

endmodule

`resetall
