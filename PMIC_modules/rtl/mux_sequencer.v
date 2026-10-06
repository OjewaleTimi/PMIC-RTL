module mux_sequencer (
    input  wire        clk,              
    input  wire        rst_n,            
    input  wire        adc_busy,        
    input  wire        adc_data_ready,  
    input  wire [7:0]  adc_data,         
    output reg         mux_select,       
    output reg         start_conv,       
    output reg  [7:0]  rf_current_reg,  
    output reg  [7:0]  flash_current_reg 
);

    localparam [1:0] SQ_IDLE       = 2'b00,
                     SQ_TRIGGER    = 2'b01,
                     SQ_WAIT_CONV  = 2'b10,
                     SQ_LATCH_DATA = 2'b11;

    reg [1:0]  seq_state;
    reg [15:0] delay_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_state         <= SQ_IDLE;
            mux_select        <= 1'b0;
            start_conv        <= 1'b0;
            rf_current_reg    <= 8'h00;
            flash_current_reg <= 8'h00;
            delay_counter     <= 16'd0;
        end else begin
            case (seq_state)
                SQ_IDLE: begin
                    start_conv <= 1'b0;
                    if (delay_counter >= 16'd5000) begin // Sampling interval delay
                        delay_counter <= 16'd0;
                        seq_state     <= SQ_TRIGGER;
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                SQ_TRIGGER: begin
                    start_conv <= 1'b1;
                    seq_state  <= SQ_WAIT_CONV;
                end

                SQ_WAIT_CONV: begin
                    start_conv <= 1'b0;
                    if (adc_data_ready) begin
                        seq_state <= SQ_LATCH_DATA;
                    end
                end

                SQ_LATCH_DATA: begin
                    if (mux_select == 1'b0) begin
                        rf_current_reg <= adc_data;
                        mux_select     <= 1'b1;      
                    end else begin
                        flash_current_reg <= adc_data;
                        mux_select        <= 1'b0;     
                    end
                    seq_state <= SQ_IDLE;
                end
            endcase
        end
    end
endmodule