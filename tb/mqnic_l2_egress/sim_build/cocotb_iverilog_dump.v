module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/mqnic_l2_egress.fst");
    $dumpvars(0, mqnic_l2_egress);
end
endmodule
