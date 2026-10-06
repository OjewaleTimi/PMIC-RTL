module i2c_peripheral_macro (
    input  wire       scl,
    inout  wire       sda,
    input  wire       rst_n,
    input  wire [7:0] rf_rail_current,
    input  wire [7:0] flash_rail_current,
    input  wire       power_source_type,
    output reg        int_pad_n,
    output wire       oc_fault
);

    // I2C slave address
    localparam [6:0] PMIC_I2C_ADDR = 7'h4A;
    
    // Register map
    localparam [7:0] ADDR_SRC_STATUS   = 8'h10,
                     ADDR_RF_CURRENT   = 8'h11,
                     ADDR_FLSH_CURRENT = 8'h12,
                     ADDR_RF_LIMIT     = 8'h13;

    reg [7:0] rf_current_limit;
    reg [7:0] sda_shift_out;
    reg [7:0] incoming_addr_byte;
    reg [7:0] incoming_data_byte;
    reg [7:0] reg_pointer;
    reg       pointer_received;
    reg [3:0] bit_index_counter;
    reg       addr_match_valid;
    reg       bus_direction_read;

    reg drive_sda_low;
    reg next_drive_sda_low;
    reg ack_pending;
    reg sda_prev;

    // Detect I2C start/stop conditions
    wire start_condition = scl && sda_prev && !sda;
    wire stop_condition  = scl && !sda_prev && sda;

    assign sda = drive_sda_low ? 1'b0 : 1'bz;
    
    // Interrupt handling for overcurrent
    assign oc_fault = (rf_rail_current > rf_current_limit);

    always @(*) begin
        int_pad_n = oc_fault ? 1'b0 : 1'bz;
    end

    // Track previous SDA state for start/stop detection
    always @(sda or negedge rst_n) begin
        if (!rst_n)
            sda_prev <= 1'b1;
        else
            sda_prev <= sda;
    end

    // Drive SDA on negedge SCL to ensure setup/hold times
    always @(negedge scl or negedge rst_n or posedge start_condition or posedge stop_condition) begin
        if (!rst_n)
            drive_sda_low <= 1'b0;
        else if (start_condition || stop_condition)
            drive_sda_low <= 1'b0;
        else
            drive_sda_low <= next_drive_sda_low;
    end

    // Main I2C state machine (posedge SCL)
    always @(posedge scl or negedge rst_n or posedge start_condition or posedge stop_condition) begin
        if (!rst_n) begin
            rf_current_limit   <= 8'h50;
            bit_index_counter  <= 4'd0;
            next_drive_sda_low <= 1'b0;
            addr_match_valid   <= 1'b0;
            bus_direction_read <= 1'b0;
            sda_shift_out      <= 8'h00;
            incoming_addr_byte <= 8'h00;
            incoming_data_byte <= 8'h00;
            ack_pending        <= 1'b0;
            reg_pointer        <= 8'h00;
            pointer_received   <= 1'b0;
        end else if (start_condition) begin
            bit_index_counter  <= 4'd0;
            addr_match_valid   <= 1'b0;
            next_drive_sda_low <= 1'b0;
            incoming_addr_byte <= 8'h00;
            ack_pending        <= 1'b0;
        end else if (stop_condition) begin
            bit_index_counter  <= 4'd0;
            addr_match_valid   <= 1'b0;
            bus_direction_read <= 1'b0;
            next_drive_sda_low <= 1'b0;
            ack_pending        <= 1'b0;
            pointer_received   <= 1'b0;
        end else begin
            bit_index_counter <= bit_index_counter + 1'b1;

            if (!addr_match_valid) begin
                // Address phase
                incoming_addr_byte <= {incoming_addr_byte[6:0], sda};
                next_drive_sda_low <= 1'b0;

                if (bit_index_counter == 4'd7) begin
                    if (incoming_addr_byte[6:0] == PMIC_I2C_ADDR) begin
                        addr_match_valid   <= 1'b1;
                        bus_direction_read <= sda;
                        next_drive_sda_low <= 1'b1; // ACK
                        ack_pending        <= 1'b1;

                        if (!sda) begin
                            pointer_received <= 1'b0;
                        end else begin
                            // Setup read data
                            case (reg_pointer)
                                ADDR_SRC_STATUS:   sda_shift_out <= {7'b0, power_source_type};
                                ADDR_RF_CURRENT:   sda_shift_out <= rf_rail_current;
                                ADDR_FLSH_CURRENT: sda_shift_out <= flash_rail_current;
                                ADDR_RF_LIMIT:     sda_shift_out <= rf_current_limit;
                                default:           sda_shift_out <= 8'hFF;
                            endcase
                        end
                    end
                    bit_index_counter <= 4'd0;
                end
            end else begin
                // Data phase
                if (bus_direction_read) begin
                    // Master reads from slave
                    next_drive_sda_low <= !sda_shift_out[7];
                    sda_shift_out      <= {sda_shift_out[6:0], 1'b1};

                    if (bit_index_counter == 4'd7) begin
                        addr_match_valid  <= 1'b0;
                        bit_index_counter <= 4'd0;
                    end
                end else if (ack_pending) begin
                    // Wait out the ACK clock cycle
                    ack_pending        <= 1'b0;
                    bit_index_counter  <= 4'd0;
                    next_drive_sda_low <= 1'b0;
                end else if (!pointer_received) begin
                    // Master writes register pointer
                    incoming_data_byte <= {incoming_data_byte[6:0], sda};
                    next_drive_sda_low <= 1'b0;

                    if (bit_index_counter == 4'd7) begin
                        reg_pointer        <= {incoming_data_byte[6:0], sda};
                        pointer_received   <= 1'b1;
                        bit_index_counter  <= 4'd0;
                        next_drive_sda_low <= 1'b1; // ACK
                        ack_pending        <= 1'b1;
                    end
                end else begin
                    // Master writes register data
                    incoming_data_byte <= {incoming_data_byte[6:0], sda};
                    next_drive_sda_low <= 1'b0;

                    if (bit_index_counter == 4'd7) begin
                        if (reg_pointer == ADDR_RF_LIMIT)
                            rf_current_limit <= {incoming_data_byte[6:0], sda};
                            
                        addr_match_valid   <= 1'b0;
                        bit_index_counter  <= 4'd0;
                        next_drive_sda_low <= 1'b1; // ACK
                    end
                end
            end
        end
    end
endmodule