`timescale 1ns / 1ns

module pmic_tb;
    reg   tb_clk;
    reg   tb_rst_n;
    reg         tb_usb_present;
    reg         tb_analog_oc_fault;
    reg         tb_master_shutdown;
    wire        tb_en_usb_switch;
    wire        tb_en_batt_switch;

    wire        tb_mux_select;
    wire [7:0]  tb_dac_out;
    reg         tb_adc_comp_out;

    reg         tb_scl;
    wire        tb_sda;
    wire        tb_int_pad_n;

    reg         sda_drive_reg;
    assign tb_sda = sda_drive_reg ? 1'b0 : 1'bz;

    pullup(tb_sda);

    localparam [6:0] PMIC_I2C_ADDR = 7'h4A;

    localparam [7:0] ADDR_SRC_STATUS   = 8'h10,
                     ADDR_RF_CURRENT   = 8'h11,
                     ADDR_FLSH_CURRENT = 8'h12,
                     ADDR_RF_LIMIT     = 8'h13;

    pmic_top uut (
        .clk                 (tb_clk),
        .rst_n               (tb_rst_n),
        .usb_present         (tb_usb_present),
        .analog_oc_fault     (tb_analog_oc_fault),
        .master_shutdown     (tb_master_shutdown),
        .adc_comp_out        (tb_adc_comp_out),
        .en_usb_switch       (tb_en_usb_switch),
        .en_batt_switch      (tb_en_batt_switch),
        .scl                 (tb_scl),
        .sda                 (tb_sda),
        .int_pad_n           (tb_int_pad_n),
        .mux_select          (tb_mux_select),
        .dac_out             (tb_dac_out)
    );

    always begin
        #10 tb_clk = ~tb_clk;
    end

    reg [7:0] targeted_analog_voltage;

    always @(posedge tb_clk) begin
        targeted_analog_voltage = (tb_mux_select == 1'b0) ? 8'h50 : 8'h30; // blocking: resolve target same-edge
        tb_adc_comp_out <= (tb_dac_out <= targeted_analog_voltage) ? 1'b1 : 1'b0;
    end

    task i2c_start;
        begin
            tb_scl        = 1'b1;
            sda_drive_reg = 1'b0;
            #200;
            sda_drive_reg = 1'b1;
            #200;
            tb_scl = 1'b0;
            #200;
        end
    endtask

    task i2c_stop;
        begin
            sda_drive_reg = 1'b1;
            tb_scl        = 1'b0;
            #200;
            tb_scl = 1'b1;
            #200;
            sda_drive_reg = 1'b0;
            #200;
        end
    endtask

    task i2c_send_byte(input [7:0] data_byte);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                tb_scl = 1'b0;
                #200;
                sda_drive_reg = !data_byte[i];
                #800;
                tb_scl = 1'b1;
                #1000;
                tb_scl = 1'b0;
                #200;
            end
            sda_drive_reg = 1'b0;
            #200;
            tb_scl = 1'b1;
            #1000;
            tb_scl = 1'b0;
            #200;
        end
    endtask

    task i2c_read_byte(output [7:0] data_byte, input send_ack);
        integer i;
        begin
            sda_drive_reg = 1'b0;
            for (i = 7; i >= 0; i = i - 1) begin
                tb_scl = 1'b0;
                #200;
                sda_drive_reg = 1'b0;
                #800;
                tb_scl = 1'b1;
                #400;
                data_byte[i] = tb_sda;
                #600;
                tb_scl = 1'b0;
                #200;
            end
            tb_scl = 1'b0;
            #200;
            sda_drive_reg = send_ack ? 1'b1 : 1'b0;
            #800;
            tb_scl = 1'b1;
            #1000;
            tb_scl = 1'b0;
            #200;
            sda_drive_reg = 1'b0;
        end
    endtask

    task i2c_write_reg(input [7:0] pointer, input [7:0] value);
        begin
            i2c_start;
            i2c_send_byte({PMIC_I2C_ADDR, 1'b0});
            i2c_send_byte(pointer);
            i2c_send_byte(value);
            i2c_stop;
        end
    endtask

    task i2c_read_reg(input [7:0] pointer, output [7:0] value, input send_ack);
        begin
            i2c_start;
            i2c_send_byte({PMIC_I2C_ADDR, 1'b0});
            i2c_send_byte(pointer);
            i2c_start;
            i2c_send_byte({PMIC_I2C_ADDR, 1'b1});
            i2c_read_byte(value, send_ack);
            i2c_stop;
        end
    endtask

    reg [7:0] read_data;

    initial begin
        $dumpfile("pmic.vcd");
        $dumpvars(0, pmic_tb);

        tb_clk             = 1'b0;
        tb_rst_n           = 1'b0;
        tb_usb_present     = 1'b0;
        tb_analog_oc_fault = 1'b0;
        tb_master_shutdown = 1'b0;
        tb_scl             = 1'b1;
        sda_drive_reg      = 1'b0;

        #100;
        tb_rst_n = 1'b1;
        #40;

        // BATTERY -> USB
        #500;
        tb_usb_present = 1'b1;
        #1000;
        $display("[%0t] source=%0d en_usb=%0b en_batt=%0b", $time, uut.w_source_type, tb_en_usb_switch, tb_en_batt_switch);

        // USB -> BATTERY
        tb_usb_present = 1'b0;
        #1000;
        $display("[%0t] source=%0d en_usb=%0b en_batt=%0b", $time, uut.w_source_type, tb_en_usb_switch, tb_en_batt_switch);

        // BATTERY -> USB
        tb_usb_present = 1'b1;
        #1000;

        // USB -> DISCONNECTED via analog OC fault (hardware trip)
        tb_analog_oc_fault = 1'b1;
        #500;
        $display("[%0t] analog fault asserted: en_usb=%0b en_batt=%0b", $time, tb_en_usb_switch, tb_en_batt_switch);
        tb_analog_oc_fault = 1'b0;
        #1000;

        // USB -> BATTERY
        tb_usb_present = 1'b0;
        #1000;

        // BATTERY -> DISCONNECTED via master_shutdown (host-commanded trip)
        tb_master_shutdown = 1'b1;
        #500;
        tb_master_shutdown = 1'b0;
        #1000;

        // BATTERY -> USB, settle before I2C traffic
        tb_usb_present = 1'b1;
        #2000;

        $display("[%0t] Before write: rf_current=0x%0h en_usb=%0b en_batt=%0b", $time, uut.w_rf_current, tb_en_usb_switch, tb_en_batt_switch);

        // Host writes a current limit BELOW the live rail reading (0x50) -> should trip i2c_oc_fault
        i2c_write_reg(ADDR_RF_LIMIT, 8'h10);
        #2000;

        #100000;
        $display("[%0t] After settling (limit=0x10, rail~0x50): en_usb=%0b en_batt=%0b int_pad_n=%0b", $time, tb_en_usb_switch, tb_en_batt_switch, tb_int_pad_n);

        i2c_read_reg(ADDR_RF_LIMIT, read_data, 1'b1);
        #2000;
        $display("RF_LIMIT readback = 0x%0h (expect 0x10)", read_data);

        i2c_read_reg(ADDR_RF_CURRENT, read_data, 1'b1);
        #2000;
        $display("RF_CURRENT readback = 0x%0h", read_data);

        // Clear the fault: raise the limit back above the rail
        i2c_write_reg(ADDR_RF_LIMIT, 8'h60);
        #100000;
        $display("[%0t] After clearing fault (limit=0x60): en_usb=%0b en_batt=%0b int_pad_n=%0b", $time, tb_en_usb_switch, tb_en_batt_switch, tb_int_pad_n);

        tb_usb_present = 1'b0;
        #1000;
        tb_usb_present = 1'b1;
        #1000;

        tb_master_shutdown = 1'b1;
        #500;
        tb_master_shutdown = 1'b0;
        #1000;

        tb_usb_present = 1'b0;
        #1000;

        $display("Simulation complete.");
        $finish;
    end

endmodule