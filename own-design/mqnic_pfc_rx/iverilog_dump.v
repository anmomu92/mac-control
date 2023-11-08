module iverilog_dump();
initial begin
    $dumpfile("mqnic_pfc_rx.fst");
    $dumpvars(0, mqnic_pfc_rx);
end
endmodule
