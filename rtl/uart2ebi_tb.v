`timescale 1ns/1ps
module uart2ebi_tb;

localparam CRC_INIT = 8'h14;
  // Parameters

  //Ports
  reg  clk=0;
  reg  rst=1;
  reg [15:0] prescale=40;
  wire  rxd;
  wire  txd;
  wire ebi_cs;
  wire ebi_rden;
  wire ebi_wren;
  wire [15:0] ebi_addr;
  reg [15:0] ebi_din=16'hABAB;
  wire [15:0] ebi_dout;
  wire  tx_busy;
  wire  rx_busy;
  wire  rx_overrun_error;
  wire  rx_frame_error;

  reg [7:0]s_axis_tdata=0;
  reg s_axis_tvalid=0;
  wire s_axis_tready;

  wire [7:0]m_axis_tdata ;
  wire m_axis_tvalid;

  integer i;
  function automatic [7:0] crc8ccitt;
  input [7:0] crcIn;
  input [7:0] data;
  begin
    crc8ccitt[0] = crcIn[0] ^ crcIn[6] ^ crcIn[7] ^ data[0] ^ data[6] ^ data[7];
    crc8ccitt[1] = crcIn[0] ^ crcIn[1] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[6];
    crc8ccitt[2] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[6];
    crc8ccitt[3] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[7] ^ data[1] ^ data[2] ^ data[3] ^ data[7];
    crc8ccitt[4] = crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ data[2] ^ data[3] ^ data[4];
    crc8ccitt[5] = crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ data[3] ^ data[4] ^ data[5];
    crc8ccitt[6] = crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[4] ^ data[5] ^ data[6];
    crc8ccitt[7] = crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ data[5] ^ data[6] ^ data[7];
  end
  endfunction

  uart #(.DATA_WIDTH(8))
  uart_inst (
      .clk(clk),
      .rst(rst),
  
      .s_axis_tdata (s_axis_tdata ),
      .s_axis_tvalid(s_axis_tvalid),
      .s_axis_tready(s_axis_tready),
      .m_axis_tdata (m_axis_tdata ),
      .m_axis_tvalid(m_axis_tvalid),
      .m_axis_tready(1'd1),

      .rxd(rxd),
      .txd(txd),
      .tx_busy(),
      .rx_busy(),
      .rx_overrun_error(),
      .rx_frame_error(),
      .prescale(prescale)
  );

  uart2ebi  uart2ebi_inst (
    .clk(clk),
    .rst(rst),
    .prescale(prescale),
    .rxd(txd),
    .txd(rxd),
    .ebi_cs(ebi_cs),
    .ebi_rden(ebi_rden),
    .ebi_wren(ebi_wren),
    .ebi_addr(ebi_addr),
    .ebi_din(ebi_din),
    .ebi_dout(ebi_dout),
    .tx_busy(tx_busy),
    .rx_busy(rx_busy),
    .rx_overrun_error(rx_overrun_error),
    .rx_frame_error(rx_frame_error)
  );

always #5  clk = ! clk ;
reg [7:0]crc_ret = CRC_INIT;
task wrs;
    input [15:0]addr;
    input [15:0]data;
    begin
        crc_ret = CRC_INIT;
        crc_ret = crc8ccitt(8'hAB,crc_ret);
        crc_ret = crc8ccitt(addr[15:8],crc_ret);
        crc_ret = crc8ccitt(addr[7:0],crc_ret);
        crc_ret = crc8ccitt(data[15:8],crc_ret);
        crc_ret = crc8ccitt(data[7:0],crc_ret);
        s_axis_tvalid = 1;
        s_axis_tdata = 8'hAB;
        @(posedge clk);
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = addr[15:8];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = addr[7:0];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = data[15:8];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = data[7:0];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = crc_ret;
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        s_axis_tvalid = 0;
    end
endtask

task rds;
    input  [15:0]addr;
    output [15:0]data;
    reg [7:0]recv[0:3];
    begin
        crc_ret = CRC_INIT;
        crc_ret = crc8ccitt(8'hAA,crc_ret);
        crc_ret = crc8ccitt(addr[15:8],crc_ret);
        crc_ret = crc8ccitt(addr[7:0],crc_ret);
        s_axis_tvalid = 1;
        s_axis_tdata = 8'hAA;
        @(posedge clk);
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = addr[15:8];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = addr[7:0];
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axis_tdata = crc_ret;
        while(!s_axis_tready)begin
            @(posedge clk);
        end
        s_axis_tvalid = 0;

        crc_ret = CRC_INIT;
        for (i = 0;i<4 ;i=i+1 ) begin
            while(!m_axis_tvalid)begin
                @(posedge clk);
            end
            recv[i] = m_axis_tdata;
            if (i!=3)
                crc_ret = crc8ccitt(m_axis_tdata,crc_ret);
            @(posedge clk);
        end
        if (crc_ret != recv[3])begin
            $display("read back crc error");
            $display("expect:0x%x, recv[3]:0x%x",crc_ret,recv[3]);
            $stop;
        end else begin
            // $display("read back: %x %x %x %x",recv[0],recv[1],recv[2],recv[3]);
        end
        data = {recv[1],recv[2]};
    end
endtask

// always @(posedge clk ) begin
//     if (m_axis_tvalid)begin
//         $display("0x%x",m_axis_tdata);
//     end
// end
reg [15:0]data_ret ;
initial begin
    $dumpfile("uart2ebi_tb.vcd");
    $dumpvars(0,uart2ebi_tb);
    #50
    rst = 0;
    #100
    wrs(16'h1234,16'h5678);
    wrs(16'h0001,16'hffee);
    rds(16'h0010,data_ret);$display("read back: %x",data_ret);
    rds(16'h0011,data_ret);$display("read back: %x",data_ret);
    rds(16'h0012,data_ret);$display("read back: %x",data_ret);
    wrs(16'h0002,16'hffee);
    wrs(16'h0003,16'hffee);
    rds(16'h0013,data_ret);$display("read back: %x",data_ret);
    rds(16'h0014,data_ret);$display("read back: %x",data_ret);
    rds(16'h0015,data_ret);$display("read back: %x",data_ret);

    wait(uart2ebi_tb.uart2ebi_inst.state == 0 && uart2ebi_tb.uart2ebi_inst.state_ebi == 0 );
    #900000
    $finish;
end

endmodule