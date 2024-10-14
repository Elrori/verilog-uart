iverilog -y ../rtl -o uart2ebi_tb.vvp ../rtl/uart2ebi_tb.v
vvp uart2ebi_tb.vvp
gtkwave uart2ebi_tb.gtkw