module uart2ebi (
    input   wire        clk,
    input   wire        rst,

    input   wire [15:0] prescale, // Fclk / (baud * 8), 125MHz:baud:115200=prescale:135    125MHz:baud:1201923=prescale:13  100MHz:baud:2500000=prescale:5

    input   wire        rxd,
    output  wire        txd,

    output  reg         ebi_cs,       /*synthesis keep=true*/
    output  reg         ebi_rden,     /*synthesis keep=true*/
    output  reg         ebi_wren,     /*synthesis keep=true*/    
    output  reg  [15:0] ebi_addr,     /*synthesis keep=true*/    
    input   wire [15:0] ebi_din,      /*synthesis keep=true*/
    output  reg  [15:0] ebi_dout,     /*synthesis keep=true*/

    output  wire        tx_busy,
    output  wire        rx_busy,
    output  wire        rx_overrun_error,
    output  wire        rx_frame_error,
    output  reg         wr_crc_err,   /*synthesis keep=true*/
    output  reg         rd_crc_err    /*synthesis keep=true*/

);
localparam CRC_INIT = 8'h14;
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

reg   [7:0] s_axis_tdata ;/*synthesis keep=true*/
reg         s_axis_tvalid;/*synthesis keep=true*/
wire        s_axis_tready;/*synthesis keep=true*/
wire  [7:0] m_axis_tdata ;/*synthesis keep=true*/
wire        m_axis_tvalid;/*synthesis keep=true*/
wire        m_axis_tready;/*synthesis keep=true*/
reg         ebi_wr_ena;
reg   [3 :0]ebi_crc;
reg   [15:0]ebi_addr_b;
reg   [15:0]ebi_data_b;
reg   [15:0]ebi_data_b2;
reg   [7 :0]crc_ret;
reg   [1 :0]state_ebi;
reg   [3 :0]cnt_ebird;
assign      m_axis_tready = 1'd1;
uart #(.DATA_WIDTH(8))
uart_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata (s_axis_tdata ),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata (m_axis_tdata ),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),

    .rxd(rxd),
    .txd(txd),
    .tx_busy(tx_busy),
    .rx_busy(rx_busy),
    .rx_overrun_error(rx_overrun_error),
    .rx_frame_error(rx_frame_error),
    .prescale(prescale)
);
// serial main
reg [3:0]state;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state       <= 'd0;
        crc_ret     <= CRC_INIT;
        ebi_addr_b  <= 'd0;
        ebi_data_b  <= 'd0;
        s_axis_tdata <= 'd0;
        s_axis_tvalid<= 'd0;
        rd_crc_err<= 1'd0;
        wr_crc_err <= 1'd0;
    end else begin
        case (state)
            0: begin
                if (m_axis_tvalid) begin
                    state           <=  (m_axis_tdata == 8'hAA)?1:
                                        (m_axis_tdata == 8'hAB)?10:
                                        state;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                end 
            end
            1: begin // rd addr
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_addr_b[15:8] <= m_axis_tdata;
                end
            end
            2: begin // rd addr
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_addr_b[7:0] <= m_axis_tdata;
                end
            end
            3: begin // rd crc
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= CRC_INIT;
                    rd_crc_err <= (crc_ret != m_axis_tdata);
                end
            end
            4: begin // rd success recv
                state <= state + 1'd1;
            end
            5: begin // rd ack head
                if (state_ebi == 3) begin
                    state <= state + 1'd1;
                    s_axis_tdata  <= 8'hAC;
                    s_axis_tvalid <= 1'd1;
                    crc_ret <= crc8ccitt(8'hAC,crc_ret);
                end
            end
            6: begin // rd ack data
                if (s_axis_tready) begin
                    state <= state + 1'd1;
                    s_axis_tdata  <= ebi_data_b2[15:8];
                    crc_ret <= crc8ccitt(ebi_data_b2[15:8],crc_ret);
                end
            end
            7: begin // rd ack data
                if (s_axis_tready) begin
                    state <= state + 1'd1;
                    s_axis_tdata  <= ebi_data_b2[7:0];
                    crc_ret <= crc8ccitt(ebi_data_b2[7:0],crc_ret);
                end
            end
            8: begin // rd ack crc
                if (s_axis_tready) begin
                    state <= state + 1'd1;
                    s_axis_tdata  <= rd_crc_err ? {crc_ret[7:1],~crc_ret[0]} : crc_ret;
                    crc_ret <= CRC_INIT;
                end
            end
            9: begin // rd ack
                if (s_axis_tready) begin
                    state <= 0;
                    s_axis_tvalid <= 1'd0;
                end
            end

            10: begin // wr addr
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_addr_b[15:8] <= m_axis_tdata;
                end
            end
            11: begin // wr addr
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_addr_b[7:0] <= m_axis_tdata;
                end
            end
            12: begin // wr data
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_data_b[15:8] <= m_axis_tdata;
                end
            end
            13: begin // wr data
                if (m_axis_tvalid) begin
                    state <= state + 1'd1;
                    crc_ret <= crc8ccitt(m_axis_tdata,crc_ret);
                    ebi_data_b[7:0] <= m_axis_tdata;
                end
            end
            14: begin // wr crc
                if (m_axis_tvalid) begin
                    if (crc_ret == m_axis_tdata)begin
                        state <= state + 1'd1;
                        wr_crc_err <= 1'd0;
                        crc_ret <= CRC_INIT;
                    end else begin
                        state <= 0;
                        wr_crc_err <= 1'd1;
                        crc_ret <= CRC_INIT;
                    end
                end
            end
            15: begin // wr success recv
                state <= 0;
            end
            default:begin
                state       <= 'd0;
                crc_ret     <= CRC_INIT;
                ebi_addr_b  <= 'd0;
                ebi_data_b  <= 'd0;
            end 
        endcase
    end
end
// ebi wr
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state_ebi    <= 0;
        ebi_cs          <= 1'd1;
        ebi_wren        <= 1'd1;
        ebi_rden        <= 1'd1;
        ebi_addr        <=  'd0;
        ebi_dout        <=  'd0;
        cnt_ebird       <=  'd0;
        ebi_data_b2     <=  'd0;
    end else begin
        case (state_ebi)
            0: begin
                if (state == 15) begin // wr
                    state_ebi <= 1;
                    ebi_cs       <= 1'd0;
                    ebi_wren     <= 1'd1;
                    ebi_rden     <= 1'd1;
                    ebi_addr     <= ebi_addr_b;
                    ebi_dout     <= {ebi_data_b[7:0],ebi_data_b[15:8]}; // revert
                end else if(state == 4)begin //rd
                    state_ebi <= 2;
                    ebi_cs       <= 1'd0;
                    ebi_wren     <= 1'd1;
                    ebi_rden     <= 1'd0;
                    ebi_addr     <= ebi_addr_b;
                end
            end
            1: begin // wr
                if (cnt_ebird == 4'd5) begin
                    state_ebi <= 0;
                    cnt_ebird    <= 4'd0;
                    ebi_cs       <= 1'd1;
                    ebi_wren     <= 1'd1;
                    ebi_rden     <= 1'd1;
                end else if(cnt_ebird == 4'd2)begin
                    ebi_wren     <= 1'd0;
                    cnt_ebird    <= cnt_ebird + 1'd1;
                end else begin
                    cnt_ebird    <= cnt_ebird + 1'd1;
                end
            end
            2: begin // rd
                if (cnt_ebird == 4'd8) begin
                    state_ebi <= state_ebi + 1'd1;
                    cnt_ebird    <= 4'd0;
                    ebi_cs       <= 1'd1;
                    ebi_wren     <= 1'd1;
                    ebi_rden     <= 1'd1;
                    ebi_data_b2  <= {ebi_din[7:0],ebi_din[15:8]};// revert
                end else begin
                    cnt_ebird       <=  cnt_ebird + 1'd1;
                end
            end
            3: begin // rd success
                state_ebi    <= 0;
            end
            default: begin
                state_ebi    <= 0;
                ebi_cs          <= 1'd1;
                ebi_wren        <= 1'd1;
                ebi_rden        <= 1'd1;
                ebi_addr        <=  'd0;
                ebi_dout        <=  'd0;
                cnt_ebird       <=  'd0;
                ebi_data_b2     <=  'd0;
            end
        endcase

    end
end
endmodule