
`include "iop.h"
module bp_l15_encoder
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   )
  (input clk_i
   , input reset_i

   , input [paddr_width_p-1:0]                         transducer_l15_address
   , input [mem_payload_width_p-1:0]                   mem_payload
   , input bp_lce_cce_nc_req_size_e                    nc_size
   , output                                            transducer_l15_req_ack

   , input                                             l15_transducer_val
   , input [3:0]                                       l15_transducer_returntype

   , input [63:0]                                      l15_transducer_data_0
   , input [63:0]                                      l15_transducer_data_1

   // L1.5 -> BP
   , output [mem_cce_resp_width_lp-1:0]                mem_resp_o
   , output                                            mem_resp_v_o
   , input                                             mem_resp_ready_i

   , output [mem_cce_data_resp_width_lp-1:0]           mem_data_resp_o
   , output                                            mem_data_resp_v_o
   , input                                             mem_data_resp_ready_i
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)

  bp_mem_cce_resp_s mem_resp_cast_o;
  bp_mem_cce_data_resp_s mem_data_resp_cast_o;

  assign mem_resp_o = mem_resp_cast_o;
  assign mem_data_resp_o = mem_data_resp_cast_o;

  logic [mem_payload_width_p-1:0] mem_payload_lo;
  logic [paddr_width_p-1:0] mem_paddr_lo;
  bp_lce_cce_nc_req_size_e nc_size_lo;

  wire load_not_store = (l15_transducer_returntype == `LOAD_RET);
  always_comb
    begin
      if (load_not_store)
        begin
          mem_data_resp_cast_o.msg_type      = e_lce_req_type_rd;
          mem_data_resp_cast_o.addr          = mem_paddr_lo;
          mem_data_resp_cast_o.payload       = mem_payload_lo;
          mem_data_resp_cast_o.non_cacheable = 1'b0; // We don't support OpenPiton uncached yet
          mem_data_resp_cast_o.nc_size       = nc_size_lo;
          mem_data_resp_cast_o.data          = {l15_transducer_data_1, l15_transducer_data_0};
        end
      else
        begin
          mem_resp_cast_o.msg_type      = e_lce_req_type_wr;
          mem_resp_cast_o.addr          = mem_paddr_lo;
          mem_resp_cast_o.payload       = mem_payload_lo;
          mem_resp_cast_o.non_cacheable = 1'b0;
          mem_resp_cast_o.nc_size       = nc_size_lo;
        end
    end

assign mem_resp_v_o = mem_resp_ready_i & l15_transducer_val & ~load_not_store;
assign mem_data_resp_v_o = mem_data_resp_ready_i & l15_transducer_val & load_not_store;

bsg_one_fifo
 #(.width_p(mem_payload_width_p+paddr_width_p+$bits(bp_lce_cce_nc_req_size_e)))
 save_queue
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i({mem_payload, transducer_l15_address, nc_size})
   ,.v_i(transducer_l15_req_ack)
   ,.ready_o(/* We assume there is only 1 outstanding request at a time */)

   ,.data_o({mem_payload_lo, mem_paddr_lo, nc_size_lo})
   ,.v_o(/* We shouldn't have a response without an initial request */)
   ,.yumi_i(l15_transducer_val)
   );

endmodule 
  
