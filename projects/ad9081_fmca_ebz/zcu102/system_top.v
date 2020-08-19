// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps


module system_top  #(
    parameter TX_JESD_L = 8,
    parameter TX_NUM_LINKS = 1,
    parameter RX_JESD_L = 8,
    parameter RX_NUM_LINKS = 1
  ) (

  input  [12:0] gpio_bd_i,
  output [ 7:0] gpio_bd_o,


  // FMC HPC IOs
  input  [1:0]  agc0,
  input  [1:0]  agc1,
  input  [1:0]  agc2,
  input  [1:0]  agc3,
  input         clkin6_n,
  input         clkin6_p,
  input         clkin10_n,
  input         clkin10_p,
  input         fpga_refclk_in_n,
  input         fpga_refclk_in_p,
  input  [RX_JESD_L*RX_NUM_LINKS-1:0]  rx_data_n,
  input  [RX_JESD_L*RX_NUM_LINKS-1:0]  rx_data_p,
  output [TX_JESD_L*TX_NUM_LINKS-1:0]  tx_data_n,
  output [TX_JESD_L*TX_NUM_LINKS-1:0]  tx_data_p,
  input  [TX_NUM_LINKS-1:0]  fpga_syncin_n,
  input  [TX_NUM_LINKS-1:0]  fpga_syncin_p,
  output [RX_NUM_LINKS-1:0]  fpga_syncout_n,
  output [RX_NUM_LINKS-1:0]  fpga_syncout_p,
  inout  [10:0] gpio,
  inout         hmc_gpio1,
  output        hmc_sync,
  input  [1:0]  irqb,
  output        rstb,
  output [1:0]  rxen,
  output        spi0_csb,
  input         spi0_miso,
  output        spi0_mosi,
  output        spi0_sclk,
  output        spi1_csb,
  output        spi1_sclk,
  inout         spi1_sdio,
  input         sysref2_n,
  input         sysref2_p,
  output [1:0]  txen,

  // PMOD0
  output        pmod0_0_1_PA_ON,
  output        pmod0_4_2_TR,
  output        pmod0_1_3_MOSI,
  output        pmod0_5_4_TX_LOAD,
  input         pmod0_2_5_MISO,
  output        pmod0_6_6_RX_LOAD,
  output        pmod0_3_7_SCLK,
  inout         pmod0_7_8_SCL,
  // PMOD1
  output        pmod1_0_1_CSB1,
  output        pmod1_4_2_CSB2,
  output        pmod1_1_3_CSB3,
  output        pmod1_5_4_CSB4,
  output        pmod1_2_5_CSB5,
  output        pmod1_6_6_5V_CTRL,
  inout         pmod1_3_7_SDA,
  output        pmod1_7_8_PWR_UP_DOWN,
  // FMC1 XM105 breakout board
  output        fmc_bob_xud1_cs_n,
  output        fmc_bob_xud1_txrx,
  output        fmc_bob_xud1_mosi,
  output        fmc_bob_xud1_if_state,
  input         fmc_bob_xud1_miso,
  output        fmc_bob_xud1_rx_amp_en,
  output        fmc_bob_xud1_sclk,
  output        fmc_bob_xud1_ctrl_pll,
  output        fmc_bob_xud2_cs_n,
  output        fmc_bob_xud2_txrx,
  output        fmc_bob_xud2_mosi,
  output        fmc_bob_xud2_if_state,
  input         fmc_bob_xud2_miso,
  output        fmc_bob_xud2_rx_amp_en,
  output        fmc_bob_xud2_sclk,
  output        fmc_bob_xud2_ctrl_pll

);

  // internal signals
  reg [26:0] pwr_up_cnt = {1'b1,26'b0};

  wire    [94:0]  gpio_i;
  wire    [94:0]  gpio_o;
  wire    [94:0]  gpio_t;
  wire    [ 2:0]  spi0_csn;

  wire    [ 2:0]  spi1_csn;
  wire            spi1_mosi;
  wire            spi1_miso;

  wire            ref_clk;
  wire            sysref;
  wire    [TX_NUM_LINKS-1:0]   tx_syncin;
  wire    [RX_NUM_LINKS-1:0]   rx_syncout;

  wire    [7:0]   rx_data_p_loc;
  wire    [7:0]   rx_data_n_loc;
  wire    [7:0]   tx_data_p_loc;
  wire    [7:0]   tx_data_n_loc;

  wire            clkin6;
  wire            clkin10;
  wire            tx_device_clk;
  wire            rx_device_clk;

  wire [7:0] spi_pmod_csn;
  wire       spi_pmod_clk;
  wire       spi_pmod_mosi;
  wire       pwr_up;
  wire       sys_clk;

  assign pmod0_1_3_MOSI = spi_pmod_mosi;
  assign pmod1_0_1_CSB1 = spi_pmod_csn[1];
  assign pmod1_4_2_CSB2 = spi_pmod_csn[2];
  assign pmod1_1_3_CSB3 = spi_pmod_csn[3];
  assign pmod1_5_4_CSB4 = spi_pmod_csn[4];
  assign pmod1_2_5_CSB5 = spi_pmod_csn[5];
  assign pmod0_3_7_SCLK = spi_pmod_clk;

  assign fmc_bob_xud1_mosi = spi_pmod_mosi;
  assign fmc_bob_xud1_cs_n = spi_pmod_csn[6];
  assign fmc_bob_xud1_sclk = spi_pmod_clk;

  assign fmc_bob_xud2_mosi = spi_pmod_mosi;
  assign fmc_bob_xud2_cs_n = spi_pmod_csn[7];
  assign fmc_bob_xud2_sclk = spi_pmod_clk;

  assign spi_pmod_miso = ~&spi_pmod_csn[5:1] ? pmod0_2_5_MISO :
                         ~spi_pmod_csn[6] ? fmc_bob_xud1_miso :
                         ~spi_pmod_csn[7] ? fmc_bob_xud2_miso :
                         1'b0;

  assign iic_rstn = 1'b1;
  // instantiations

  IBUFDS_GTE4 i_ibufds_ref_clk (
    .CEB (1'd0),
    .I (fpga_refclk_in_p),
    .IB (fpga_refclk_in_n),
    .O (ref_clk),
    .ODIV2 ());

  IBUFDS i_ibufds_sysref (
    .I (sysref2_p),
    .IB (sysref2_n),
    .O (sysref));

  IBUFDS i_ibufds_tx_device_clk (
    .I (clkin6_p),
    .IB (clkin6_n),
    .O (clkin6));

  IBUFDS i_ibufds_rx_device_clk (
    .I (clkin10_p),
    .IB (clkin10_n),
    .O (clkin10));

  genvar i;
  generate
  for(i=0;i<TX_NUM_LINKS;i=i+1) begin : g_tx_buffers
    IBUFDS i_ibufds_syncin (
      .I (fpga_syncin_p[i]),
      .IB (fpga_syncin_n[i]),
      .O (tx_syncin[i]));
  end

  for(i=0;i<RX_NUM_LINKS;i=i+1) begin : g_rx_buffers
    OBUFDS i_obufds_syncout (
      .I (rx_syncout[i]),
      .O (fpga_syncout_p[i]),
      .OB (fpga_syncout_n[i]));
  end
  endgenerate

  BUFG i_tx_device_clk (
    .I (clkin6),
    .O (tx_device_clk)
  );

  BUFG i_rx_device_clk (
    .I (clkin10),
    .O (rx_device_clk)
  );
  // spi

  assign spi0_csb   = spi0_csn[0];
  assign spi1_csb   = spi1_csn[0];


  ad_3w_spi #(.NUM_OF_SLAVES(1)) i_spi (
    .spi_csn (spi1_csn[0]),
    .spi_clk (spi1_sclk),
    .spi_mosi (spi1_mosi),
    .spi_miso (spi1_miso),
    .spi_sdio (spi1_sdio),
    .spi_dir ());

  // gpios

  ad_iobuf #(.DATA_WIDTH(12)) i_iobuf (
    .dio_t (gpio_t[43:32]),
    .dio_i (gpio_o[43:32]),
    .dio_o (gpio_i[43:32]),
    .dio_p ({hmc_gpio1,       // 43
             gpio[10:0]}));   // 42-32

  assign gpio_i[44] = agc0[0];
  assign gpio_i[45] = agc0[1];
  assign gpio_i[46] = agc1[0];
  assign gpio_i[47] = agc1[1];
  assign gpio_i[48] = agc2[0];
  assign gpio_i[49] = agc2[1];
  assign gpio_i[50] = agc3[0];
  assign gpio_i[51] = agc3[1];
  assign gpio_i[52] = irqb[0];
  assign gpio_i[53] = irqb[1];

  assign hmc_sync         = gpio_o[54];
  assign rstb             = gpio_o[55];
  assign rxen[0]          = gpio_o[56];
  assign rxen[1]          = gpio_o[57];
  assign txen[0]          = gpio_o[58];
  assign txen[1]          = gpio_o[59];
  assign dac_fifo_bypass  = gpio_o[60];

  // PMOD GPIOs
  assign pmod0_0_1_PA_ON       = gpio_o[61];
  assign pmod0_4_2_TR          = gpio_o[62];
  assign pmod0_5_4_TX_LOAD     = gpio_o[63];
  assign pmod0_6_6_RX_LOAD     = gpio_o[64];
  assign pmod1_6_6_5V_CTRL     = gpio_o[65];
  assign pmod1_7_8_PWR_UP_DOWN = pwr_up | gpio_o[66];

  // XUD FMC BOB
  assign fmc_bob_xud1_txrx = gpio_o[67];
  assign fmc_bob_xud1_if_state = gpio_o[68];
  assign fmc_bob_xud1_rx_amp_en = gpio_o[69];
  assign fmc_bob_xud1_ctrl_pll = gpio_o[70];
  assign fmc_bob_xud2_txrx = gpio_o[71];
  assign fmc_bob_xud2_if_state = gpio_o[72];
  assign fmc_bob_xud2_rx_amp_en = gpio_o[73];
  assign fmc_bob_xud2_ctrl_pll = gpio_o[74];

  /* Board GPIOS. Buttons, LEDs, etc... */
  assign gpio_i[20: 8] = gpio_bd_i;
  assign gpio_bd_o = gpio_o[7:0];

  // Unused GPIOs
  assign gpio_i[94:54] = gpio_o[94:54];
  assign gpio_i[31:21] = gpio_o[31:21];
  assign gpio_i[7:0] = gpio_o[7:0];

  system_wrapper i_system_wrapper (
    .sys_clk (sys_clk),
    .gpio_i (gpio_i),
    .gpio_o (gpio_o),
    .gpio_t (gpio_t),
    .spi0_csn (spi0_csn),
    .spi0_miso (spi0_miso),
    .spi0_mosi (spi0_mosi),
    .spi0_sclk (spi0_sclk),
    .spi1_csn (spi1_csn),
    .spi1_miso (spi1_miso),
    .spi1_mosi (spi1_mosi),
    .spi1_sclk (spi1_sclk),
    // FMC HPC
    .rx_data_0_n (rx_data_n_loc[0]),
    .rx_data_0_p (rx_data_p_loc[0]),
    .rx_data_1_n (rx_data_n_loc[1]),
    .rx_data_1_p (rx_data_p_loc[1]),
    .rx_data_2_n (rx_data_n_loc[2]),
    .rx_data_2_p (rx_data_p_loc[2]),
    .rx_data_3_n (rx_data_n_loc[3]),
    .rx_data_3_p (rx_data_p_loc[3]),
    .rx_data_4_n (rx_data_n_loc[4]),
    .rx_data_4_p (rx_data_p_loc[4]),
    .rx_data_5_n (rx_data_n_loc[5]),
    .rx_data_5_p (rx_data_p_loc[5]),
    .rx_data_6_n (rx_data_n_loc[6]),
    .rx_data_6_p (rx_data_p_loc[6]),
    .rx_data_7_n (rx_data_n_loc[7]),
    .rx_data_7_p (rx_data_p_loc[7]),
    .tx_data_0_n (tx_data_n_loc[0]),
    .tx_data_0_p (tx_data_p_loc[0]),
    .tx_data_1_n (tx_data_n_loc[1]),
    .tx_data_1_p (tx_data_p_loc[1]),
    .tx_data_2_n (tx_data_n_loc[2]),
    .tx_data_2_p (tx_data_p_loc[2]),
    .tx_data_3_n (tx_data_n_loc[3]),
    .tx_data_3_p (tx_data_p_loc[3]),
    .tx_data_4_n (tx_data_n_loc[4]),
    .tx_data_4_p (tx_data_p_loc[4]),
    .tx_data_5_n (tx_data_n_loc[5]),
    .tx_data_5_p (tx_data_p_loc[5]),
    .tx_data_6_n (tx_data_n_loc[6]),
    .tx_data_6_p (tx_data_p_loc[6]),
    .tx_data_7_n (tx_data_n_loc[7]),
    .tx_data_7_p (tx_data_p_loc[7]),
    .ref_clk_q0 (ref_clk),
    .ref_clk_q1 (ref_clk),
    .rx_device_clk (rx_device_clk),
    .tx_device_clk (tx_device_clk),
    .rx_sync_0 (rx_syncout),
    .tx_sync_0 (tx_syncin),
    .rx_sysref_0 (sysref),
    .tx_sysref_0 (sysref),
    .dac_fifo_bypass (dac_fifo_bypass),
    // PMOD stuff
    .iic_pmod_scl_io (pmod0_7_8_SCL),
    .iic_pmod_sda_io (pmod1_3_7_SDA),
    .spi_pmod_clk_i (spi_pmod_clk),
    .spi_pmod_clk_o (spi_pmod_clk),
    .spi_pmod_csn_i (spi_pmod_csn),
    .spi_pmod_csn_o (spi_pmod_csn),
    .spi_pmod_sdi_i (spi_pmod_miso),
    .spi_pmod_sdo_i (spi_pmod_mosi),
    .spi_pmod_sdo_o (spi_pmod_mosi)
  );

  assign rx_data_p_loc[TX_JESD_L*TX_NUM_LINKS-1:0] = rx_data_p[TX_JESD_L*TX_NUM_LINKS-1:0];
  assign rx_data_n_loc[TX_JESD_L*TX_NUM_LINKS-1:0] = rx_data_n[TX_JESD_L*TX_NUM_LINKS-1:0];

  assign tx_data_p[TX_JESD_L*TX_NUM_LINKS-1:0] = tx_data_p_loc[TX_JESD_L*TX_NUM_LINKS-1:0];
  assign tx_data_n[TX_JESD_L*TX_NUM_LINKS-1:0] = tx_data_n_loc[TX_JESD_L*TX_NUM_LINKS-1:0];

  // Power up logic
  // Delay power up with 1.3s
  assign pwr_up = pwr_up_cnt[25];
  always @(posedge sys_clk) begin
    if (pwr_up_cnt[26]) begin
      pwr_up_cnt <= pwr_up_cnt + 1;
    end
  end

endmodule

// ***************************************************************************
// ***************************************************************************
