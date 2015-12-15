/*  
    Copyright (c) 2015 LeafLabs LLC
    Author: Charlie Lamantia
    Date: December 2015

    Data model of the Intan RHD2000 series electrophysiology interface
    chip: http://www.intantech.com/files/Intan_RHD2000_series_datasheet.pdf
*/

`timescale 1ns / 1ps

`include "llLib.v"

module rhd2000_dm #(
    parameter CHANNELS = 32,
    parameter REVISION = 1,
    parameter UNIPOLAR = 0,
    parameter ID       = 1
)(
    // packed array to use as multi-channel input stimulus for simulating ADC return timing
    input   [(16 * CHANNELS) - 1:0] analogIn,
    
    input   nCs,
    input   mosi,
    input   sClk,

    output reg aux,
    output reg miso
);

    // internal ram
    reg [7:0] ram [17:0];

    // internal rom
    reg [7:0] rom [8:0];

    // access variables
    integer address = 0;
    reg [7:0] data = 0;

    
    // initialize ram and rom
    initial begin
        ////// ROM
        // Company Designation
        rom[0] = "I";
        rom[1] = "N";
        rom[2] = "T";
        rom[3] = "A";
        rom[4] = "N";
        // Die Revision
        rom[5] = REVISION;
        // Unipolar/Bipolar Amplifiers
        rom[6] = UNIPOLAR;
        // Number of amplifiers
        rom[7] = CHANNELS;
        // Intan Tech Chip ID
        rom[8] = ID;

        ////// RAM
        // ADC Configuration and Amplifier Fast Settle
        ram[0] = {  2'd3, // ADC Reference BW
                    1'b0, // Amp Fast Settle
                    1'b1, // Amp Vref Enable
                    2'd3, // ADC Comparator Bias
                    2'd2  // ADC Comparator Select
                };
        // Supply Sensor and ADC Buffer Bias Current
        ram[1] = {  1'bX,
                    1'b0, // VDD Sense Enable
                    6'd32 // ADC Buffer Bias (see table in datasheet p.27)
                };
        // MUX Bias Current
        ram[2] = { 2'bXX, 6'd40 // see table in datasheet p.27
                };
        // MUX Load, Temperature Sensor, and Auxiliary Digital Output
        ram[3] = {  3'd0, // MUX Load
                    2'd0, // Temperature Sensors Switches
                    1'b0, // Temperature Sensor Enable
                    1'b0, // Auxiliary Output High Impedance Enable
                    1'b0  // Auxiliary Output
                };
        // ADC Output Format and DSP Offset Removal
        ram[4] = {  1'b0, // Weak MISO
                    1'b1, // Two's Complement Enable
                    1'b0, // Absolute Value Filter
                    1'b0, // DSP Enable, Filters ADC Data with Highpass Filter
                    4'd0  // Select Cutoff Frequency for Highpass Filter
                };
        // Impedance Check Control
        ram[5] = {  1'bX,
                    1'b0, // DAC Enable
                    1'b0, // Capacitive Load Enable
                    2'd0, // Capacitor Value for Waveform Generator
                    1'b0, // Connects All Electrodes To The "elec_test" Input Pin
                    1'b0, // Selects Positive (0) or Negative (1) Input Pin for Testing (Only 2216)
                    1'b0  // Impedance Check Enable
                };
        // Impedance Check DAC
        ram[6] = 8'd0; // Value to Write to Impedance Checking DAC
        // Impedance Check Amplifier Select
        ram[7] = {  2'bXX,
                    6'd0  // Select the Amplifier Whos Electrode is Being Checked
                };
        // On-Chip Amplifier Bandwidth Select
        ram[8] = {  1'b0, // Enable Off-Chip Resistor "RH1"
                    1'bX,
                    6'd0  // Upper Cutoff Frequency of the Biopotential Amplifiers (RH1 DAC1)
                };
        ram[9] = {  1'b0, // When On-Chip Resistors are Used, Sets Aux1 to ADC Input (AUX1)
                    2'bXX,
                    5'd0  // Upper Cutoff Frequency of the Biopotential Amplifiers (RH1 DAC2)
                };
        ram[10] = { 1'b0, // Enable Off-Chip Resistor "RH2"
                    1'bX,
                    6'd0  // Upper Cutoff Frequency of the Biopotential Amplifiers (RH2 DAC1)
                };
        ram[11] = { 1'b0, // When On-Chip Resistors are Used, Sets Aux1 to ADC Input (AUX2)
                    2'bXX,
                    5'd0  // Upper Cutoff Frequency of the Biopotential Amplifiers (RH2 DAC2)
                };
        ram[12] = { 1'b0, // Enable Off-Chip Resistor "RL"
                    1'bX,
                    6'd0  // Upper Cutoff Frequency of the Biopotential Amplifiers (RL DAC1)
                };
        ram[13] = { 1'b0, // When On-Chip Resistors are Used, Sets Aux1 to ADC Input (AUX3)
                    1'b0, // Lower Cutoff Frequency of the Biopotential Amplifiers (RL DAC3)
                    6'd0  // Lower Cutoff Frequency of the Biopotential Amplifiers (RL DAC2)
                };
        // Individual Amplifier Enable
        ram[14] = 8'b1111_1111; // 7,  6,  5,  4,  3,  2,  1,  0
        ram[15] = 8'b1111_1111; // 15, 14, 13, 12, 11, 10, 9,  8
        ram[16] = 8'b1111_1111; // 23, 22, 21, 20, 19, 18, 17, 16
        ram[17] = 8'b1111_1111; // 31, 30, 29, 28, 27, 26, 25, 24
    end


    // io buffers
    reg [15:0] iBuffer = 0;
    reg [15:0] oBuffer = 16'hXXXX;
    reg [15:0] out = 16'hXXXX;

    // bit position counter
    integer bCount = 15;

    // random delay value
    integer delay = 0;

    // convert signals
    reg convert = 0;
    integer cChannel = 0;

    // calibrate signals
    reg calibrate = 0;
    integer calCounter = 0;

    
    // wire the auxiliary output pin
    always @(ram[3]) begin
        if (ram[3][1]) begin
            aux = 1'bZ;
        end else if (ram[3][0]) begin
            aux = 1'b1;
        end else begin
            aux = 1'b0;
        end
    end

    
    // main loop
    always begin
        while (1) begin

            // wait for the falling edge of chip select
            @(negedge nCs);

            // zero out input buffer
            iBuffer = 0;

            if (convert) begin // capture data from specified adc channel
                oBuffer = analogIn[(cChannel) * 16 +: 16];
                convert = 0;
            end
            
            // add a random delay
            delay = llLib.RANDRANGE (12, 6);
            #delay;

            // place first bit on miso
            bCount = 15;
            miso = out[bCount];

            ////// finish io transaction
            repeat (15) begin
                
                // wait for rising edge of serial clock
                @(posedge sClk);

                // add a random delay
                delay = llLib.RANDRANGE (12, 6);
                #delay;

                // capture mosi value into buffer
                iBuffer[bCount] = mosi;

                // wait for falling edge of serial clock
                @(negedge sClk);

                // add a random delay
                delay = llLib.RANDRANGE (12, 6);
                #delay;

                // move to next bit position
                bCount = bCount - 1;

                // place data onto miso line
                miso = out[bCount];
            end

            ////// Capture final mosi bit
            //
            // wait for rising edge of serial clock
            @(posedge sClk);
            
            // add a random small delay
            delay = llLib.RANDRANGE (12, 6);
            #delay;
            
            // capture mosi value into buffer
            iBuffer[bCount] = mosi;

            // wait for the device to be de-selected
            @(posedge nCs);

            
            // relax output line
            if (ram[4][7] == 1'b1) begin
                miso = 1'bZ;
            end else begin
                miso = 1'b0;
            end

            
            // set data to be transmitted over miso next cycle
            out = oBuffer;

            
            if (!calibrate) begin
                // parse input command
                case (iBuffer[15:14])
                    
                    // convert
                    2'b00 : begin
                        cChannel = iBuffer >> 8;
                        convert = 1;
                    end

                    // calibrate
                    2'b01 : begin
                        if (iBuffer[13:8] == 6'b010101) begin
                            calCounter = 8;
                            calibrate = 1;
                        end

                        oBuffer = { ram[4][6], 15'd0 };
                    end

                    // write
                    2'b10 : begin
                        address = iBuffer[13:8];
                        data = iBuffer[7:0];

                        if (address <= 17) begin
                            ram[address] = data;
                        end

                        oBuffer = { {8{1'b1}}, data };
                    end

                    // read
                    2'b11 : begin
                        address = iBuffer[13:8];

                        if (address <= 17) begin
                            oBuffer = { 8'd0, ram[address] };
                        
                        end else if (address >= 40 && address <= 44) begin
                            oBuffer = { 8'd0, rom[address - 40] };
                        
                        end else if (address >= 60) begin
                            oBuffer = { 8'd0, rom[address - 55] };
                        end
                    end
                endcase
            
            end else begin
                calCounter = calCounter - 1;

                oBuffer = { ram[4][6], 15'd0 };

                // dummy command
                iBuffer = { 2'b01, 14'd0 };

                if (calCounter == 0) begin
                    calibrate = 0;
                end
            end
        end
    end



 endmodule