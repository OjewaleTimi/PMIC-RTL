module pmic_top (
    input  wire  clk, rst_n,
    input  wire  usb_present, analog_oc_fault, master_shutdown, adc_comp_out,
    input  wire  scl,
    inout  wire  sda,
    output wire  en_usb_switch, en_batt_switch, int_pad_n, mux_select,
    output wire [7:0] dac_out
);

    wire  w_source_type;
    wire [7:0] w_adc_data;
    wire  w_adc_busy, w_adc_ready, w_start_conv;
    wire [7:0] w_rf_current, w_flash_current;

   wire w_analog_oc_fault_n;
  assign w_analog_oc_fault_n = ~analog_oc_fault;

wire w_i2c_oc_fault;

    pp_controller u_power_path (
        .clk(clk), .rst_n(rst_n),
        .usb_present(usb_present),
        .analog_oc_fault_n(w_analog_oc_fault_n),
        .i2c_oc_fault(w_i2c_oc_fault),
        .master_shutdown(master_shutdown),
        .en_usb_switch(en_usb_switch), .en_batt_switch(en_batt_switch),
        .power_source_status(w_source_type)
    );

  
    adc_controller u_adc (
        .clk(clk), .rst_n(rst_n), .start_conv(w_start_conv), .comp_out(adc_comp_out),
        .dac_out(dac_out), .adc_busy(w_adc_busy), .adc_data_ready(w_adc_ready), .adc_data(w_adc_data)
    );

    // MUX Switching Scheduler Instance
    mux_sequencer u_mux (
        .clk(clk), .rst_n(rst_n), .adc_busy(w_adc_busy), .adc_data_ready(w_adc_ready), .adc_data(w_adc_data),
        .mux_select(mux_select), .start_conv(w_start_conv), .rf_current_reg(w_rf_current), .flash_current_reg(w_flash_current)
    );

    // I2C Bus Macro Instance
    i2c_peripheral_macro u_i2c (
        .scl(scl), .sda(sda), .rst_n(rst_n),
        .rf_rail_current(w_rf_current), .flash_rail_current(w_flash_current),
        .power_source_type(w_source_type), .int_pad_n(int_pad_n),
        .oc_fault(w_i2c_oc_fault)
    );
endmodule