// This module describes the P-Mesh Cache Engine (PCE) which is the interface
// between the L1 Caches of BlackParrot and the L1.5 Cache of OpenPiton

`include "bp_common_defines.svh"
`include "bp_pce_l15_if.svh"

module bp_pce
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_unicore_parrotpiton_cfg
   ,parameter block_width_p = 128
   ,parameter fill_width_p = 128
   ,parameter assoc_p = 2
   ,parameter sets_p = 256
   ,parameter pce_id_p = 1 // 0 = I$, 1 = D$
   ,parameter metadata_latency_p = 1
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
   `declare_bp_pce_l15_if_widths(paddr_width_p, dword_width_gp)

   // Cache parameters
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_gp
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(assoc_p)
   , localparam block_offset_width_lp = word_offset_width_lp + byte_offset_width_lp
   , localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p)
   , localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p)

   )
  ( input                                          clk_i
  , input                                          reset_i

  // Cache side
  , input [cache_req_width_lp-1:0]                 cache_req_i
  , input                                          cache_req_v_i
  , output logic                                   cache_req_yumi_o
  , output logic                                   cache_req_busy_o
  , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
  , input                                          cache_req_metadata_v_i
  , output logic                                   cache_req_complete_o
  , output logic                                   cache_req_critical_tag_o
  , output logic                                   cache_req_critical_data_o
  , output logic                                   cache_req_credits_full_o
  , output logic                                   cache_req_credits_empty_o

  // Cache side
  , output logic [cache_data_mem_pkt_width_lp-1:0] cache_data_mem_pkt_o
  , output logic                                   cache_data_mem_pkt_v_o
  , input                                          cache_data_mem_pkt_yumi_i

  , output logic [cache_tag_mem_pkt_width_lp-1:0]  cache_tag_mem_pkt_o
  , output logic                                   cache_tag_mem_pkt_v_o
  , input                                          cache_tag_mem_pkt_yumi_i

  , output logic [cache_stat_mem_pkt_width_lp-1:0] cache_stat_mem_pkt_o
  , output logic                                   cache_stat_mem_pkt_v_o
  , input                                          cache_stat_mem_pkt_yumi_i

  // PCE -> L1.5
  , output logic                                   pce_l15_req_v_o
  , output logic [bp_pce_l15_req_width_lp-1:0]     pce_l15_req_o
  , input                                          pce_l15_req_ready_i

  // L1.5 -> PCE
  , input                                          l15_pce_ret_v_i
  , input        [bp_l15_pce_ret_width_lp-1:0]     l15_pce_ret_i
  , output logic                                   l15_pce_ret_yumi_o

  );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `declare_bp_pce_l15_if(paddr_width_p, dword_width_gp);

  bp_cache_req_s cache_req_cast_i;
  bp_cache_req_metadata_s cache_req_metadata_cast_i;
  assign cache_req_cast_i = cache_req_i;
  assign cache_req_metadata_cast_i = cache_req_metadata_i;

  bp_cache_data_mem_pkt_s cache_data_mem_pkt_cast_o;
  bp_cache_tag_mem_pkt_s cache_tag_mem_pkt_cast_o, inval_cache_tag_mem_pkt_cast_o;
  bp_cache_stat_mem_pkt_s cache_stat_mem_pkt_cast_o, inval_cache_stat_mem_pkt_cast_o;

  bp_pce_l15_req_s pce_l15_req_cast_o;
  bp_l15_pce_ret_s l15_pce_ret_cast_i;
  assign pce_l15_req_o = pce_l15_req_cast_o;
  assign l15_pce_ret_cast_i = l15_pce_ret_i;

  logic cache_req_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(cache_req_yumi_o | pce_l15_req_v_o)
     ,.clear_i(cache_req_complete_o)
     ,.data_o(cache_req_v_r)
     );

  bp_cache_req_s cache_req_r;
  bsg_dff_reset_en
    #(.width_p($bits(bp_cache_req_s)))
    cache_req_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.en_i(cache_req_yumi_o)
      ,.data_i(cache_req_cast_i)
      ,.data_o(cache_req_r)
      );

  logic cache_req_metadata_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1)
     ,.clear_over_set_p((metadata_latency_p == 1))
     )
   metadata_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(cache_req_metadata_v_i)
     ,.clear_i(cache_req_yumi_o)
     ,.data_o(cache_req_metadata_v_r)
     );
 
  bp_cache_req_metadata_s cache_req_metadata_r;
  bsg_dff_en_bypass
    #(.width_p($bits(bp_cache_req_metadata_s)))
    metadata_reg
     (.clk_i(clk_i)

      ,.en_i(cache_req_metadata_v_i)
      ,.data_i(cache_req_metadata_i)
      ,.data_o(cache_req_metadata_r)
      );

  enum logic [3:0] {e_reset, e_clear, e_ready, e_uc_store_wait, e_send_req, e_uc_read_wait, e_amo_lr_wait, e_amo_sc_wait, e_amo_op_wait, e_read_wait} state_n, state_r;
  logic [`BSG_SAFE_CLOG2(coh_noc_max_credits_p)-1:0] no_return_count_lo;

  wire uc_store_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store} & cache_req_cast_i.subop inside {e_req_store};
  wire wt_store_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};
  wire no_return_amo_v_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store} & cache_req_cast_i.subop inside {e_req_amosc, e_req_amoswap, e_req_amoadd, e_req_amoxor, e_req_amoand
                                                                                                                           , e_req_amoor, e_req_amomin, e_req_amomax, e_req_amominu, e_req_amomaxu};

  wire store_resp_v_li = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_st_ack) & ~l15_pce_ret_cast_i.noncacheable;
  wire load_resp_v_li  = l15_pce_ret_v_i & l15_pce_ret_cast_i.rtntype inside {e_load_ret, e_ifill_ret};
  wire inval_v_li      = l15_pce_ret_v_i & l15_pce_ret_cast_i.rtntype inside {e_evict_req, e_st_ack};
  wire is_ifill_ret_nc = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_ifill_ret) & l15_pce_ret_cast_i.noncacheable;
  wire is_load_ret_nc  = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_load_ret) & l15_pce_ret_cast_i.noncacheable;
  wire is_ifill_ret    = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_ifill_ret) & ~l15_pce_ret_cast_i.noncacheable;
  wire is_load_ret     = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_load_ret) & ~l15_pce_ret_cast_i.noncacheable;
  wire is_amo_lrsc_ret = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_atomic_ret) & l15_pce_ret_cast_i.atomic;
  // Fetch + Op atomics also set the noncacheable bit as 1
  wire is_amo_op_ret   = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_atomic_ret) & l15_pce_ret_cast_i.atomic & l15_pce_ret_cast_i.noncacheable;

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire amo_lr_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo} & cache_req_r.subop inside {e_req_amolr};
  wire amo_sc_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo} & cache_req_r.subop inside {e_req_amosc};
  wire amo_op_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo} & cache_req_r.subop inside {e_req_amoswap, e_req_amoadd, e_req_amoxor, e_req_amoand, e_req_amoor
                                                                                                         ,e_req_amomin, e_req_amomax, e_req_amominu, e_req_amomaxu};

  logic [index_width_lp-1:0] index_cnt;
  logic index_up;
  bsg_counter_clear_up
    #(.max_val_p(sets_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
    index_counter
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i('0)
     ,.up_i(index_up)

     ,.count_o(index_cnt)
     );
  
  wire index_done = (index_cnt == sets_p-1);

  assign cache_req_credits_full_o  = (state_r != e_ready);
  assign cache_req_credits_empty_o = (state_r == e_ready);
  assign cache_req_critical_tag_o  = '0;
  assign cache_req_critical_data_o = '0;
  assign cache_req_busy_o          = cache_req_credits_full_o;

  logic l15_pce_ret_yumi_lo;
  assign l15_pce_ret_yumi_o = l15_pce_ret_yumi_lo | store_resp_v_li;

  // Assigning PCE->$ packets
  assign cache_data_mem_pkt_o = cache_data_mem_pkt_cast_o;
  assign cache_tag_mem_pkt_o = inval_v_li ? inval_cache_tag_mem_pkt_cast_o : cache_tag_mem_pkt_cast_o;
  assign cache_stat_mem_pkt_o = inval_v_li ? inval_cache_stat_mem_pkt_cast_o : cache_stat_mem_pkt_cast_o;

  // This is definitely over-provisioned, exponential?
  localparam backoff_cnt_lp = 255;
  logic backoff, lr_enable;
  logic [`BSG_WIDTH(backoff_cnt_lp)-1:0] count_lo;

  bsg_counter_clear_up
   #(.max_val_p(backoff_cnt_lp)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   sc_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(backoff)
     ,.up_i(~lr_enable)
     ,.count_o(count_lo)
     );
  assign lr_enable = (count_lo == backoff_cnt_lp);

  always_comb
    begin
      cache_req_yumi_o = '0;

      index_up = '0;

      cache_tag_mem_pkt_cast_o  = '0;
      inval_cache_tag_mem_pkt_cast_o = '0;
      cache_tag_mem_pkt_v_o     = '0;
      cache_data_mem_pkt_cast_o = '0;
      cache_data_mem_pkt_v_o    = '0;
      cache_stat_mem_pkt_cast_o = '0;
      inval_cache_stat_mem_pkt_cast_o = '0;
      cache_stat_mem_pkt_v_o    = '0;

      cache_req_complete_o = '0;

      backoff = 1'b0;
      
      pce_l15_req_cast_o = '0;
      pce_l15_req_v_o = '0;

      l15_pce_ret_yumi_lo = '0;
      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            l15_pce_ret_yumi_lo = (l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_int_ret));

            state_n = l15_pce_ret_yumi_lo
                          ? e_clear 
                          : e_reset;
          end
        e_clear:
          begin
            cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            cache_tag_mem_pkt_cast_o.index  = index_cnt;
            cache_tag_mem_pkt_v_o = 1'b1;

            cache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            cache_stat_mem_pkt_cast_o.index  = index_cnt;
            cache_stat_mem_pkt_v_o = 1'b1;

            index_up = cache_tag_mem_pkt_yumi_i & cache_stat_mem_pkt_yumi_i;

            cache_req_complete_o = (index_done & index_up);

            state_n = cache_req_complete_o 
                          ? e_ready 
                          : e_clear;
          end

        e_ready:
          begin
            cache_req_yumi_o = cache_req_v_i & pce_l15_req_ready_i;
            if (uc_store_v_li | wt_store_v_li | no_return_amo_v_li) begin
              pce_l15_req_cast_o.rqtype  = no_return_amo_v_li ? e_amo_req : e_store_req;
              pce_l15_req_cast_o.nc      = uc_store_v_li | no_return_amo_v_li;
              pce_l15_req_cast_o.address = cache_req_cast_i.addr;
              pce_l15_req_cast_o.size    = (cache_req_cast_i.size == e_size_1B)
                                           ? e_l15_size_1B
                                           : (cache_req_cast_i.size == e_size_2B)
                                             ? e_l15_size_2B
                                             : (cache_req_cast_i.size == e_size_4B)
                                               ? e_l15_size_4B
                                               : e_l15_size_8B;
              pce_l15_req_cast_o.amo_op  = bp_pce_l15_amo_type_e'((cache_req_cast_i.subop == e_req_amoswap)
                                                                   ? e_amo_op_swap
                                                                   : (cache_req_cast_i.subop == e_req_amoadd)
                                                                   ? e_amo_op_add
                                                                   : (cache_req_cast_i.subop == e_req_amoand)
                                                                   ? e_amo_op_and
                                                                   : (cache_req_cast_i.subop == e_req_amoor)
                                                                   ? e_amo_op_or
                                                                   : (cache_req_cast_i.subop == e_req_amoxor)
                                                                   ? e_amo_op_xor
                                                                   : (cache_req_cast_i.subop == e_req_amomax)
                                                                   ? e_amo_op_max
                                                                   : (cache_req_cast_i.subop == e_req_amomin)
                                                                   ? e_amo_op_min
                                                                   : (cache_req_cast_i.subop == e_req_amomaxu)
                                                                   ? e_amo_op_maxu
                                                                   : (cache_req_cast_i.subop == e_req_amominu)
                                                                   ? e_amo_op_minu
                                                                   : (cache_req_cast_i.subop == e_req_amosc)
                                                                   ? e_amo_op_sc
                                                                   : e_amo_op_none);

              // OpenPiton is big endian whereas BlackParrot is little endian
              pce_l15_req_cast_o.data    = (cache_req_cast_i.size == e_size_1B)
                                            ? {8{cache_req_cast_i.data[0+:8]}}
                                            : (cache_req_cast_i.size == e_size_2B)
                                               ? {4{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8]}}
                                               : (cache_req_cast_i.size == e_size_4B)
                                                  ? {2{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                                       cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8]}}
                                                  : {cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                                     cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8],
                                                     cache_req_cast_i.data[32+:8], cache_req_cast_i.data[40+:8],
                                                     cache_req_cast_i.data[48+:8], cache_req_cast_i.data[56+:8]};
              pce_l15_req_v_o = cache_req_yumi_o;
              state_n = (cache_req_yumi_o & ~wt_store_v_li) ? e_uc_store_wait : e_ready;
            end
            else begin
              state_n = cache_req_yumi_o 
                        ? e_send_req 
                        : e_ready;
            end 
          end

        e_uc_store_wait:
          begin
            l15_pce_ret_yumi_lo = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype inside {e_st_ack, e_atomic_ret}) & l15_pce_ret_cast_i.noncacheable;

            state_n = l15_pce_ret_yumi_lo
                      ? e_ready
                      : e_uc_store_wait;
          end
        
        e_send_req:
          begin
            if (miss_v_li) begin
              pce_l15_req_cast_o.rqtype = (pce_id_p == 1)
                                          ? e_load_req
                                          : e_imiss_req;

              pce_l15_req_cast_o.nc = 1'b0;
              pce_l15_req_cast_o.size = (pce_id_p == 1)
                                        ? e_l15_size_16B
                                        : e_l15_size_32B;
              pce_l15_req_cast_o.address = (pce_id_p == 1)
                                           ? {cache_req_r.addr[paddr_width_p-1:4], 4'b0}
                                           : {cache_req_r.addr[paddr_width_p-1:5], 5'b0};
              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1)
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.hit_or_repl_way}
                                            : cache_req_metadata_r.hit_or_repl_way;
              pce_l15_req_v_o = pce_l15_req_ready_i & cache_req_metadata_v_r;

              state_n = pce_l15_req_v_o
                        ? e_read_wait
                        : e_send_req;
            end
            else if (uc_load_v_li) begin
              pce_l15_req_cast_o.rqtype = (pce_id_p == 1)
                                            ? e_load_req
                                            : e_imiss_req; 
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.hit_or_repl_way}
                                            : cache_req_metadata_r.hit_or_repl_way;

              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_uc_read_wait
                        : e_send_req;
            end
            else if (amo_lr_v_li & (pce_id_p == 1)) begin
              if (lr_enable) begin
                pce_l15_req_cast_o.rqtype = e_amo_req; 
                pce_l15_req_cast_o.amo_op = e_amo_op_lr;
                pce_l15_req_cast_o.nc = 1'b1;
                pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                      ? e_l15_size_1B
                                      : (cache_req_r.size == e_size_2B)
                                        ? e_l15_size_2B
                                        : (cache_req_r.size == e_size_4B)
                                          ? e_l15_size_4B
                                          : e_l15_size_8B;

                pce_l15_req_cast_o.address = cache_req_r.addr;
                pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                              ? {cache_req_r.addr[11], cache_req_metadata_r.hit_or_repl_way}
                                              : cache_req_metadata_r.hit_or_repl_way;

                pce_l15_req_v_o = pce_l15_req_ready_i;
              end

              state_n = pce_l15_req_v_o
                        ? e_amo_lr_wait
                        : e_send_req;
            end
            else if (amo_sc_v_li & (pce_id_p == 1)) begin
              pce_l15_req_cast_o.rqtype = e_amo_req; 
              pce_l15_req_cast_o.amo_op = e_amo_op_sc;
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.data = (cache_req_r.size == e_size_1B)
                                    ? {8{cache_req_r.data[0+:8]}}
                                    : (cache_req_r.size == e_size_2B)
                                      ? {4{cache_req_r.data[0+:8], cache_req_r.data[8+:8]}}
                                      : (cache_req_r.size == e_size_4B)
                                        ? {2{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                              cache_req_r.data[16+:8], cache_req_r.data[24+:8]}}
                                        : {cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                            cache_req_r.data[16+:8], cache_req_r.data[24+:8],
                                            cache_req_r.data[32+:8], cache_req_r.data[40+:8],
                                            cache_req_r.data[48+:8], cache_req_r.data[56+:8]};

              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_amo_sc_wait
                        : e_send_req;
            end
            else if (amo_op_v_li & (pce_id_p == 1)) begin
              pce_l15_req_cast_o.rqtype = e_amo_req;
              // TODO: Can this be done in a more concise manner?
              pce_l15_req_cast_o.amo_op = bp_pce_l15_amo_type_e'((cache_req_r.subop == e_req_amoswap)
                                                                  ? e_amo_op_swap
                                                                  : (cache_req_r.subop == e_req_amoadd)
                                                                  ? e_amo_op_add
                                                                  : (cache_req_r.subop == e_req_amoand)
                                                                  ? e_amo_op_and
                                                                  : (cache_req_r.subop == e_req_amoor)
                                                                  ? e_amo_op_or
                                                                  : (cache_req_r.subop == e_req_amoxor)
                                                                  ? e_amo_op_xor
                                                                  : (cache_req_r.subop == e_req_amomax)
                                                                  ? e_amo_op_max
                                                                  : (cache_req_r.subop == e_req_amomin)
                                                                  ? e_amo_op_min
                                                                  : (cache_req_r.subop == e_req_amomaxu)
                                                                  ? e_amo_op_maxu
                                                                  : (cache_req_r.subop == e_req_amominu)
                                                                  ? e_amo_op_minu
                                                                  : e_amo_op_none);

              // Fetch + Op atomics need to have the nc bit set
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.data = (cache_req_r.size == e_size_1B)
                                    ? {8{cache_req_r.data[0+:8]}}
                                    : (cache_req_r.size == e_size_2B)
                                      ? {4{cache_req_r.data[0+:8], cache_req_r.data[8+:8]}}
                                      : (cache_req_r.size == e_size_4B)
                                        ? {2{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                              cache_req_r.data[16+:8], cache_req_r.data[24+:8]}}
                                        : {cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                            cache_req_r.data[16+:8], cache_req_r.data[24+:8],
                                            cache_req_r.data[32+:8], cache_req_r.data[40+:8],
                                            cache_req_r.data[48+:8], cache_req_r.data[56+:8]};

              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.hit_or_repl_way}
                                            : cache_req_metadata_r.hit_or_repl_way;

              pce_l15_req_v_o = pce_l15_req_ready_i;
              state_n = pce_l15_req_v_o
                        ? e_amo_op_wait
                        : e_send_req;
            end
          end

        e_uc_read_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            // TODO: This might need some work (especially for SD cards)
            // based on how OP does this.
            if (is_ifill_ret_nc)
              begin
                cache_data_mem_pkt_cast_o.data = ((cache_req_r.addr[3] == 1'b1) && (cache_req_r.addr[2] == 1'b0))
                                                  ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                     l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                     l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                     l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}
                                                  : ((cache_req_r.addr[3] == 1'b1) && (cache_req_r.addr[2] == 1'b1))
                                                     ? {l15_pce_ret_cast_i.data_1[32+:8],  l15_pce_ret_cast_i.data_1[40+:8],    
                                                        l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8],
                                                        l15_pce_ret_cast_i.data_1[0+:8], l15_pce_ret_cast_i.data_1[8+:8],
                                                        l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8]}
                                                     : ((cache_req_r.addr[3] == 1'b0) && (cache_req_r.addr[2] == 1'b1))
                                                        ? {l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                           l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8],
                                                           l15_pce_ret_cast_i.data_0[0+:8], l15_pce_ret_cast_i.data_0[8+:8],
                                                           l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8]}
                                                        : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                           l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                           l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                           l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};
              end
            else if (is_load_ret_nc)
              begin
                cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                                 ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                    l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                    l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                    l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]} 
                                                 : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                    l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                    l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                    l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};
              end
            cache_data_mem_pkt_v_o = is_ifill_ret_nc | is_load_ret_nc;
            
            l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
            cache_req_complete_o = cache_data_mem_pkt_yumi_i;

            state_n = cache_req_complete_o 
                          ? e_ready 
                          : e_uc_read_wait;
          end
        
        e_amo_lr_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_lrsc_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              // TODO: This might need some work based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}   
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_lr_wait;
            end
            else begin
              state_n = e_amo_lr_wait;
            end
          end
        
        e_amo_sc_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_lrsc_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              // Size for an atomic operation is either 32 bits or 64 bits. SC
              // returns either a 0 or 1
              cache_data_mem_pkt_cast_o.data = {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              if (cache_data_mem_pkt_yumi_i & (cache_data_mem_pkt_cast_o.data != '0)) begin
                backoff = 1'b1;
              end

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_sc_wait;
            end
            else begin
              state_n = e_amo_sc_wait;
            end
          end

        e_amo_op_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_op_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              // TODO: This might need some work based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}   
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_op_wait;
            end
            else begin
              state_n = e_amo_op_wait;
            end
          end

        e_read_wait:
          begin
            // Checking for return types here since we could also have
            // invalidations coming in at anytime
            cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
            cache_data_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            cache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.hit_or_repl_way;
            cache_data_mem_pkt_cast_o.data = is_ifill_ret
                                             ? {l15_pce_ret_cast_i.data_3[0+:8],  l15_pce_ret_cast_i.data_3[8+:8],
                                                l15_pce_ret_cast_i.data_3[16+:8], l15_pce_ret_cast_i.data_3[24+:8],
                                                l15_pce_ret_cast_i.data_3[32+:8], l15_pce_ret_cast_i.data_3[40+:8],
                                                l15_pce_ret_cast_i.data_3[48+:8], l15_pce_ret_cast_i.data_3[56+:8],
                                                l15_pce_ret_cast_i.data_2[0+:8],  l15_pce_ret_cast_i.data_2[8+:8],       
                                                l15_pce_ret_cast_i.data_2[16+:8], l15_pce_ret_cast_i.data_2[24+:8],
                                                l15_pce_ret_cast_i.data_2[32+:8], l15_pce_ret_cast_i.data_2[40+:8],
                                                l15_pce_ret_cast_i.data_2[48+:8], l15_pce_ret_cast_i.data_2[56+:8],
                                                l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8],       
                                                l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]}
                                             : {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8],       
                                                l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};
            cache_data_mem_pkt_cast_o.fill_index = 1'b1;
            cache_data_mem_pkt_v_o = is_ifill_ret | is_load_ret;

            cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            cache_tag_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            cache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.hit_or_repl_way;
            cache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[block_offset_width_lp+index_width_lp+:ctag_width_p];
            cache_tag_mem_pkt_cast_o.state = is_ifill_ret ? e_COH_S : e_COH_M;
            cache_tag_mem_pkt_v_o = is_ifill_ret | is_load_ret;

            l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;
            cache_req_complete_o = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;

            state_n = cache_req_complete_o 
                            ? e_ready 
                            : e_read_wait;
          end
        default: state_n = e_reset;
      endcase

      // Need to support invalidations no matter what
      // Supporting inval all way and single way for both caches. OpenPiton
      // doesn't support inval all way for dcache and inval specific way for
      // icache
      if (inval_v_li) begin
        if (((pce_id_p == 0) && l15_pce_ret_cast_i.inval_icache_inval) || ((pce_id_p == 1) && l15_pce_ret_cast_i.inval_dcache_inval)) begin
          inval_cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_pce_ret_cast_i.inval_way[1], l15_pce_ret_cast_i.inval_address_15_4[6:0]} 
                                                  : l15_pce_ret_cast_i.inval_address_15_4[7:1];
          inval_cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
          inval_cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_pce_ret_cast_i.inval_way[0] 
                                                  : l15_pce_ret_cast_i.inval_way;
          inval_cache_tag_mem_pkt_cast_o.state  = e_COH_I;
          cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;

          l15_pce_ret_yumi_lo = cache_tag_mem_pkt_yumi_i;
        end
        else if (((pce_id_p == 0) && l15_pce_ret_cast_i.inval_icache_all_way) || ((pce_id_p == 1) && l15_pce_ret_cast_i.inval_dcache_all_way)) begin
          inval_cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_pce_ret_cast_i.inval_way[1], l15_pce_ret_cast_i.inval_address_15_4[6:0]} 
                                                  : l15_pce_ret_cast_i.inval_address_15_4[7:1];
          inval_cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
          inval_cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_pce_ret_cast_i.inval_way[0] 
                                                  : l15_pce_ret_cast_i.inval_way;
          cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;
          l15_pce_ret_yumi_lo = cache_tag_mem_pkt_yumi_i;
        end
      end
      
    end
    
  always_ff @(posedge clk_i)
    begin
      if(reset_i) begin
        state_r <= e_reset;
      end
      else begin
        state_r <= state_n;
      end
    end

endmodule
