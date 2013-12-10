
module dmac_dest_mm_axi (
	input                               m_axi_aclk,
	input                               m_axi_aresetn,

	input                               req_valid,
	output                              req_ready,
	input [31:C_ADDR_ALIGN_BITS]        req_address,
	input [3:0]                         req_last_burst_length,
	input [2:0]                         req_last_beat_bytes,

	input                               enable,
	output                              enabled,
	input                               pause,
	input                               sync_id,
	output                              sync_id_ret,

	output                              response_valid,
	input                               response_ready,
	output [1:0]                        response_resp,
	output                              response_resp_eot,

	input  [C_ID_WIDTH-1:0]             request_id,
	output [C_ID_WIDTH-1:0]             response_id,

	output [C_ID_WIDTH-1:0]             data_id,
	output [C_ID_WIDTH-1:0]             address_id,
	input                               data_eot,
	input                               address_eot,
	input                               response_eot,

	input                               fifo_valid,
	output                              fifo_ready,
	input [C_M_AXI_DATA_WIDTH-1:0]      fifo_data,

	// Write address
	input                               m_axi_awready,
	output                              m_axi_awvalid,
	output [31:0]                       m_axi_awaddr,
	output [ 7:0]                       m_axi_awlen,
	output [ 2:0]                       m_axi_awsize,
	output [ 1:0]                       m_axi_awburst,
	output [ 2:0]                       m_axi_awprot,
	output [ 3:0]                       m_axi_awcache,

	// Write data
	output [C_M_AXI_DATA_WIDTH-1:0]     m_axi_wdata,
	output [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
	input                               m_axi_wready,
	output                              m_axi_wvalid,
	output                              m_axi_wlast,

	// Write response
	input                               m_axi_bvalid,
	input  [ 1:0]                       m_axi_bresp,
	output                              m_axi_bready
);

parameter C_ID_WIDTH = 3;
parameter C_M_AXI_DATA_WIDTH = 64;
parameter C_ADDR_ALIGN_BITS = 3;
parameter C_DMA_LENGTH_WIDTH = 24;

wire [C_ID_WIDTH-1:0] data_id;
wire [C_ID_WIDTH-1:0] address_id;

reg [(C_M_AXI_DATA_WIDTH/8)-1:0] wstrb;

wire address_req_valid;
wire address_req_ready;
wire data_req_valid;
wire data_req_ready;

wire address_enabled;
wire data_enabled;
assign sync_id_ret = sync_id;

splitter #(
	.C_NUM_M(2)
) i_req_splitter (
	.clk(m_axi_aclk),
	.resetn(m_axi_aresetn),
	.s_valid(req_valid),
	.s_ready(req_ready),
	.m_valid({
		address_req_valid,
		data_req_valid
	}),
	.m_ready({
		address_req_ready,
		data_req_ready
	})
);

dmac_address_generator #(
	.C_DMA_LENGTH_WIDTH(C_DMA_LENGTH_WIDTH),
	.C_ADDR_ALIGN_BITS(C_ADDR_ALIGN_BITS),
	.C_ID_WIDTH(C_ID_WIDTH)
) i_addr_gen (
	.clk(m_axi_aclk),
	.resetn(m_axi_aresetn),

	.enable(enable),
	.enabled(address_enabled),
	.pause(pause),

	.id(address_id),
	.wait_id(request_id),
	.sync_id(sync_id),

	.req_valid(address_req_valid),
	.req_ready(address_req_ready),
	.req_address(req_address),
	.req_last_burst_length(req_last_burst_length),

	.eot(address_eot),

	.addr_ready(m_axi_awready),
	.addr_valid(m_axi_awvalid),
	.addr(m_axi_awaddr),
	.len(m_axi_awlen),
	.size(m_axi_awsize),
	.burst(m_axi_awburst),
	.prot(m_axi_awprot),
	.cache(m_axi_awcache)
);

wire _fifo_ready;

dmac_data_mover # (
	.C_ID_WIDTH(C_ID_WIDTH),
	.C_DATA_WIDTH(C_M_AXI_DATA_WIDTH)
) i_data_mover (
	.s_axi_aclk(m_axi_aclk),
	.s_axi_aresetn(m_axi_aresetn),

	.enable(address_enabled),
	.enabled(data_enabled),

	.request_id(address_id),
	.response_id(data_id),
	.sync_id(sync_id),
	.eot(data_eot),

	.req_valid(data_req_valid),
	.req_ready(data_req_ready),
	.req_last_burst_length(req_last_burst_length),

	.s_axi_valid(fifo_valid),
	.s_axi_ready(_fifo_ready),
	.s_axi_data(fifo_data),
	.m_axi_valid(m_axi_wvalid),
	.m_axi_ready(m_axi_wready),
	.m_axi_data(m_axi_wdata),
	.m_axi_last(m_axi_wlast)
);

assign fifo_ready = _fifo_ready | ~enabled;

always @(*)
begin
	if (data_eot & m_axi_wlast) begin
		wstrb <= (1 << (req_last_beat_bytes + 1)) - 1;
	end else begin
		wstrb <= 8'b11111111;
	end
end

assign m_axi_wstrb = wstrb;
 
dmac_response_handler #(
	.C_ID_WIDTH(C_ID_WIDTH)
) i_response_handler (
	.clk(m_axi_aclk),
	.resetn(m_axi_aresetn),
	.bvalid(m_axi_bvalid),
	.bready(m_axi_bready),
	.bresp(m_axi_bresp),

	.enable(data_enabled),
	.enabled(enabled),

	.id(response_id),
	.wait_id(data_id),
	.sync_id(sync_id),

	.eot(response_eot),

	.resp_valid(response_valid),
	.resp_ready(response_ready),
	.resp_resp(response_resp),
	.resp_eot(response_resp_eot)
);

endmodule
