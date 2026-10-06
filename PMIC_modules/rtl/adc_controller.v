module adc_controller (
    input  wire   clk,
    input  wire   rst_n,
    input  wire   start_conv,
    input  wire   comp_out,
    output reg  [7:0] dac_out,
    output reg   adc_busy,
    output reg   adc_data_ready,
    output reg  [7:0]  adc_data
);

    localparam [2:0] ST_IDLE    = 3'b000,
                     ST_SAMPLE  = 3'b001,
                     ST_WAIT    = 3'b010,  
                     ST_CONVERT = 3'b011,
                     ST_DONE    = 3'b100;

    reg [2:0] state;
    reg [2:0] bit_index;
    reg [7:0] sar_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            dac_out        <= 8'h00;
            adc_busy       <= 1'b0;
            adc_data_ready <= 1'b0;
            adc_data       <= 8'h00;
            bit_index      <= 3'd7;
            sar_reg        <= 8'h00;
        end else begin
            case (state)
                ST_IDLE: begin
                    adc_data_ready <= 1'b0;
                    if (start_conv) begin
                        state    <= ST_SAMPLE;
                        adc_busy <= 1'b1;
                        sar_reg  <= 8'h00;
                    end else begin
                        adc_busy <= 1'b0;
                    end
                end

                ST_SAMPLE: begin
                    bit_index <= 3'd7;
                    sar_reg   <= 8'b1000_0000;
                    dac_out   <= 8'b1000_0000;
                    state     <= ST_WAIT;
                end

          
                ST_WAIT: begin
                    state <= ST_CONVERT;
                end

                ST_CONVERT: begin
                    if (comp_out == 1'b1) begin
                        sar_reg[bit_index] <= 1'b1;
                    end else begin
                        sar_reg[bit_index] <= 1'b0;
                    end

                    if (bit_index == 3'd0) begin
                        state <= ST_DONE;
                    end else begin
                        bit_index <= bit_index - 1'b1;
                        sar_reg[bit_index - 1'b1] <= 1'b1;
                        dac_out <= (comp_out == 1'b1  ? (sar_reg | (8'b1 << bit_index)) : (sar_reg & ~(8'b1 << bit_index))) | (8'b1 << (bit_index - 1'b1));
                        state <= ST_WAIT;
                    end
                end

                ST_DONE: begin
                    adc_data       <= sar_reg;
                    adc_data_ready <= 1'b1;
                    adc_busy       <= 1'b0;
                    state          <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule