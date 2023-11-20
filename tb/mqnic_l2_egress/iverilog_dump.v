module iverilog_dump();
initial begin
    $dumpfile("mqnic_l2_egress.fst");
    $dumpvars(0, mqnic_l2_egress);
end
endmodule
