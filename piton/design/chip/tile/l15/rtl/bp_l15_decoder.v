
module bp_l15_decoder
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   )
  (input clk_i
   , input reset_i

   // BP -> L1.5 
   , input [cce_mem_cmd_width_lp-1:0]                  mem_cmd_i
   , input                                             mem_cmd_v_i
   , output                                            mem_cmd_yumi_o

   , input [cce_mem_data_cmd_width_lp-1:0]             mem_data_cmd_i
   , input                                             mem_data_cmd_v_i
   , output                                            mem_data_cmd_yumi_o

   // OpenPiton side
   , output [4:0]                                      transducer_l15_rqtype
   , output [2:0]                                      transducer_l15_size
   , output [paddr_width_p-1:0]                        transducer_l15_address
   , output [63:0]                                     transducer_l15_data
   , output                                            transducer_l15_nc
   , output                                            transducer_l15_val
   , input                                             l15_transducer_ack
   , input                                             l15_transducer_header_ack

   , output [mem_payload_width_p-1:0]                  mem_payload
   , output bp_lce_cce_nc_req_size_e                   nc_size

   // Unused OpenPiton side connections
   , output [3:0]                                      transducer_l15_amo_op
   , output [0:0]                                      transducer_l15_threadid
   , output                                            transducer_l15_prefetch
   , output                                            transducer_l15_invalidate_cacheline
   , output                                            transducer_l15_blockstore
   , output                                            transducer_l15_blockinitstore
   , output                                            transducer_l15_l1rplway
   , output                                            transducer_l15_data_next_entry
   , output                                            transducer_l15_csm_data
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
  
  wire unused = &{l15_transducer_header_ack};

  bp_cce_mem_cmd_s mem_cmd_cast_i;
  bp_cce_mem_data_cmd_s mem_data_cmd_cast_i;

  assign mem_cmd_cast_i = mem_cmd_i;
  assign mem_data_cmd_cast_i = mem_data_cmd_cast_i;
  
  always_comb
    begin
      if (mem_cmd_v_i)
        begin
          transducer_l15_rqtype  = (mem_cmd_cast_i.msg_type == e_lce_req_type_rd) ? `LOAD_RQ : `STORE_RQ;
          case (mem_cmd_cast_i.nc_size)
            e_lce_nc_req_1: transducer_l15_size = `PCX_SZ_1B;
            e_lce_nc_req_2: transducer_l15_size = `PCX_SZ_2B;
            e_lce_nc_req_4: transducer_l15_size = `PCX_SZ_4B;
            e_lce_nc_req_8: transducer_l15_size = `PCX_SZ_8B;
            default: transducer_l15_size = '0;
          endcase
          transducer_l15_address = mem_cmd_cast_i.addr;
          transducer_l15_data    = '0;
          transducer_l15_nc      = '0; // Always cache in OpenPiton for now

          mem_payload = mem_cmd_cast_i.mem_payload;
          nc_size     = mem_cmd_cast_i.nc_size;
        end
      else
        begin
          transducer_l15_rqtype  = (mem_data_cmd_cast_i.msg_type == e_lce_req_type_rd) ? `LOAD_RQ : `STORE_RQ;
          case (mem_data_cmd_cast_i.nc_size)
            e_lce_nc_req_1: transducer_l15_size = `PCX_SZ_1B;
            e_lce_nc_req_2: transducer_l15_size = `PCX_SZ_2B;
            e_lce_nc_req_4: transducer_l15_size = `PCX_SZ_4B;
            e_lce_nc_req_8: transducer_l15_size = `PCX_SZ_8B;
            default: transducer_l15_size = '0;
          endcase
          transducer_l15_address = mem_data_cmd_cast_i.addr;
          transducer_l15_data    = mem_data_cmd_cast_i.data;
          transducer_l15_nc      = '0; // Always cache in OpenPiton for now

          mem_payload = mem_data_cmd_cast_i.mem_payload;
          nc_size     = mem_data_cmd_cast_i.nc_size;
        end
    end
  
  // Assume that we will always service cmd over data_cmd
  assign transducer_l15_val   = mem_cmd_v_i | mem_data_cmd_v_i;
  assign mem_cmd_yumi_o       = l15_transducer_ack & mem_cmd_v_i;
  assign mem_data_cmd_yumi_o  = l15_transducer_ack & ~mem_cmd_v_i;
  
  // Tie off unused signals
  assign transducer_l15_amo_op                 = '0;
  assign transducer_l15_threadid               = '0;
  assign transducer_l15_prefetch               = '0;
  assign transducer_l15_invalidate_cacheline   = '0;
  assign transducer_l15_blockstore             = '0;
  assign transducer_l15_blockinitstore         = '0;
  assign transducer_l15_l1rplway               = '0;
  assign transducer_l15_data_next_entry        = '0;
  assign transducer_l15_csm_data               = '0;

endmodule 
  
