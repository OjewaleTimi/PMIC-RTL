module pp_controller ( 
    input  wire    clk,                  
    input  wire    rst_n,                
    input  wire    usb_present,          
    input  wire    analog_oc_fault_n,      
    input  wire    master_shutdown, 
    input  wire    i2c_oc_fault,        
    output reg     en_usb_switch,        
    output reg     en_batt_switch,        
    output reg     power_source_status   
);

    // FSM States
    localparam [2:0] STATE_DISCONNECTED   = 3'b000,
                     STATE_BATTERY        = 3'b001,
                     STATE_USB            = 3'b010,
                     STATE_BBM_BAT_TO_USB = 3'b011,
                     STATE_BBM_USB_TO_BAT = 3'b100;

    // BBM Dead-time Configuration
    localparam [3:0] BBM_CYCLES = 4'd15;

    reg [2:0] current_state, next_state;
    reg [3:0] bbm_counter, next_bbm_counter;
    
    wire      emergency_trip;

    // Fault condition evaluates asynchronously to logic
    assign emergency_trip = (!analog_oc_fault_n) || i2c_oc_fault || master_shutdown;

    // Sequential Logic: State and Counter Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_DISCONNECTED;   
            bbm_counter   <= 4'd0;
        end else begin
            current_state <= next_state;
            bbm_counter   <= next_bbm_counter;
        end
    end

    // Combinational Logic: Next State and Counter Routing
    always @(*) begin
        // Default hold values
        next_state       = current_state;
        next_bbm_counter = bbm_counter;
        
        if (emergency_trip) begin
            next_state       = STATE_DISCONNECTED;  
            next_bbm_counter = 4'd0;
        end else begin
            case (current_state)
                STATE_DISCONNECTED: begin
                    next_state       = usb_present ? STATE_USB : STATE_BATTERY;
                    next_bbm_counter = 4'd0;
                end
                
                STATE_BATTERY: begin
                    if (usb_present) begin
                        next_state       = STATE_BBM_BAT_TO_USB; 
                        next_bbm_counter = 4'd0;
                    end
                end
                
                STATE_USB: begin
                    if (!usb_present) begin
                        next_state       = STATE_BBM_USB_TO_BAT; 
                        next_bbm_counter = 4'd0;
                    end
                end

                STATE_BBM_BAT_TO_USB: begin
                    if (bbm_counter < BBM_CYCLES - 1) begin
                        next_bbm_counter = bbm_counter + 1'b1;
                    end else begin
                        next_state       = STATE_USB;
                        next_bbm_counter = 4'd0;
                    end
                end

                STATE_BBM_USB_TO_BAT: begin
                    if (bbm_counter < BBM_CYCLES - 1) begin
                        next_bbm_counter = bbm_counter + 1'b1;
                    end else begin
                        next_state       = STATE_BATTERY;
                        next_bbm_counter = 4'd0;
                    end
                end
                
                default: begin
                    next_state       = STATE_BATTERY;
                    next_bbm_counter = 4'd0;
                end
            endcase
        end
    end

    // Combinational Logic: Output Generation
    always @(*) begin
        // Default safe state (both switches OFF, prevents latches)
        en_usb_switch       = 1'b0;
        en_batt_switch      = 1'b0;
        power_source_status = 1'b0; 

        case (current_state)
            STATE_DISCONNECTED: begin
                en_usb_switch       = 1'b0;
                en_batt_switch      = 1'b0;
                power_source_status = 1'b0;
            end
            
            STATE_BATTERY: begin
                en_usb_switch       = 1'b0;
                en_batt_switch      = 1'b1; 
                power_source_status = 1'b0; 
            end
            
            STATE_USB: begin
                en_usb_switch       = 1'b1; 
                en_batt_switch      = 1'b0;
                power_source_status = 1'b1; 
            end

            STATE_BBM_BAT_TO_USB: begin
                // Both switches OFF during dead-time
                en_usb_switch       = 1'b0; 
                en_batt_switch      = 1'b0;
                power_source_status = 1'b0; // Maintain previous telemetry until handoff completes
            end

            STATE_BBM_USB_TO_BAT: begin
                // Both switches OFF during dead-time
                en_usb_switch       = 1'b0; 
                en_batt_switch      = 1'b0;
                power_source_status = 1'b1; // Maintain previous telemetry until handoff completes
            end
            
            default: begin
                en_usb_switch       = 1'b0;
                en_batt_switch      = 1'b1;
                power_source_status = 1'b0;
            end
        endcase
    end

endmodule