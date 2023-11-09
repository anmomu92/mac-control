// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright (c) 2021-2023 The Regents of the University of California
 */

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * NIC layer 2 egress processing
 */
module mqnic_l2_egress #
(
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,

    // ¿INCLUDE KEEP ENABLE SIGNAL?

    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1

    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH = AXIS_USER_WIDTH,
    parameter MCF_PARAMS_SIZE = 18
)
(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * Transmit data input (DATA COMES FROM INTERNAL DATAPATH)
     */
    input  wire [AXIS_DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire                        s_axis_tlast,
    input  wire [AXIS_USER_WIDTH-1:0]  s_axis_tuser,

    input  wire [ID_WIDTH-1:0]         s_axis_tid,
    input  wire [DEST_WIDTH-1:0]       s_axis_tdest,

    /*
     * Transmit data output (DATA IS SENT TO OUTSIDE)
     */
    output wire [AXIS_DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire                        m_axis_tlast,
    output wire [AXIS_USER_WIDTH-1:0]  m_axis_tuser,

    output wire [ID_WIDTH-1:0]         m_axis_tid,
    output wire [DEST_WIDTH-1:0]       m_axis_tdest,

    /*
     * MAC control frame interface
     * ---------------------------
     * It contains the mcf (either lfc or pfc)
     */
    input  wire                          mcf_valid,
    output wire                          mcf_ready,
    input  wire [47:0]                   mcf_eth_dst,
    input  wire [47:0]                   mcf_eth_src,
    input  wire [15:0]                   mcf_eth_type,
    input  wire [15:0]                   mcf_opcode,
    input  wire [MCF_PARAMS_SIZE*8-1:0]  mcf_params,
    input  wire [ID_WIDTH-1:0]           mcf_id,
    input  wire [DEST_WIDTH-1:0]         mcf_dest,
    input  wire [USER_WIDTH-1:0]         mcf_user,

    /*
     * Pause interface
     */
    // It is asserted when the FIFO is congested
    input  wire                          tx_pause_req,
    output wire                          tx_pause_ack,

    /*
     * Status
     */
     output wire                          stat_tx_mcf
);

// placeholder
assign m_axis_tdata = s_axis_tdata;
assign m_axis_tkeep = s_axis_tkeep;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;
assign m_axis_tuser = s_axis_tuser;

/*
This module sends the DATA FRAME or the MAC CONTROL FRAME
if it has received a pause request

*/
mac_ctrl_tx #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .KEEP_ENABLE(AXIS_DATA_WIDTH>8),
    .KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .ID_ENABLE(ID_ENABLE),
    .ID_WIDTH(ID_WIDTH),
    .DEST_ENABLE(DEST_ENABLE),
    .DEST_WIDTH(DEST_WIDTH),
    .USER_ENABLE(USER_ENABLE),
    .USER_WIDTH(USER_WIDTH),
    .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
)(
    .clk(clk),
    .rst(rst),

    /*
     * AXI stream input
     */
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tid(s_axis_tid),
    .s_axis_tdest(s_axis_tdest),
    .s_axis_tuser(s_axis_tuser),

    /*
     * AXI stream output
     */
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tid(m_axis_tid),
    .m_axis_tdest(m_axis_tdest),
    .m_axis_tuser(m_axis_tuser),

    /*
     * MAC control frame interface
     */
    .mcf_valid(mcf_valid),
    .mcf_ready(mcf_ready),
    .mcf_eth_dst(mcf_eth_dst),
    .mcf_eth_src(mcf_eth_src),
    .mcf_eth_type(mcf_eth_type),
    .mcf_opcode(mcf_opcode),
    .mcf_params(mcf_params),
    .mcf_id(mcf_id),
    .mcf_dest(mcf_dest),
    .mcf_user(mcf_user),

    /*
     * Pause interface
     */
    .tx_pause_req(tx_pause_req),
    .tx_pause_ack(tx_pause_ack),

    /*
     * Status
     */
    .stat_tx_mcf(stat_tx_mcf)
);


endmodule

`resetall
