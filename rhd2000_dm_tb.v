/*  
    Copyright (c) 2015 LeafLabs LLC
    Author: Charlie Lamantia
    Date: December 2015

    Testbench for rhd2000_dm. Exercises all available SPI commands including
    ADC data conversion via concatenated input array "analogIn".
*/

`timescale 1ns / 1ps

`define STARTDELAY 100

`include "llLib.v"

module rhd2000_dm_tb #(
		parameter CHANNELS = 32,
		parameter REVISION = 1,
		parameter UNIPOLAR = 1,
		parameter ID = 1
	)();

	////// unit under test //////
	reg [511:0]	analog;
	reg 		nCs = 1;
	reg			sclk;
	wire		miso;
	reg 		mosi = 0;
	wire 		aux;
	rhd2000_dm #(
		.CHANNELS	(CHANNELS ),
		.REVISION	(REVISION ),
		.UNIPOLAR	(UNIPOLAR ),
		.ID 		(ID       )
	)
	uut	(
		.analogIn	(analog   ),
		.nCs		(nCs      ),
		.sClk 		(sclk     ),
		.mosi		(mosi     ),
		.miso		(miso     ),
		.aux		(aux      ) 	
	);

	////// read/write transaction //////
	task SPI_TRANSACTION;
		input [15:0] command;
		output [15:0] return;

		reg [3:0] bit;
		reg [15:0] temp;
		begin
			nCs = 0;
			bit = 4'd15;

			repeat (16) begin
				#20.8
					mosi = command[bit];

				#10.4;
					sclk = 1;
					temp[bit] = miso;

				#20.8
					sclk = 0;

				bit = bit - 4'd1;
			end

			#41.6;
				nCs = 1;

			return = temp;

			// minimum time between transactions
			#154.0;
		end
	endtask


	////// tests //////
	
	// convert
	task testConvert;
			reg [15:0] channel;
			reg [15:0] return;
			reg [15:0] dummy;
		begin
			channel = 0;
			dummy = { 2'b01, 6'b101010, 8'd0 };

			SPI_TRANSACTION ( channel << 8, return); // read first channel, return X

			channel = channel + 1;

			SPI_TRANSACTION ( channel << 8, return); // read second channel, return X

			repeat (32) begin
				channel = channel + 1;

				SPI_TRANSACTION (channel << 8, return); // channel itterator, valid returns

				// assert
				if (return != channel - 1) begin
					
					$display("!TEST FAILED!  Capture channel %d returned %b.", channel - 1, return);
				end				
			end
		end
	endtask

	// calibration
	task testCalibration;
			reg [15:0] calibrate;
			reg [15:0] return;
			reg [15:0] dummy;
			
			integer itteration;
		begin
			calibrate = { 2'b01, 6'b010101, 8'b0 };
			dummy = { 2'b01, 6'b101010, 8'b0 };
			itteration = 0;

			SPI_TRANSACTION (calibrate, return); // send calibration command, return x
			
			repeat (10) begin
				itteration = itteration + 1;

				SPI_TRANSACTION (dummy, return); // 9 cycles of dummy

				// assert
				if (return != {1'b1, 15'b0}) begin
					
					$display("!TEST FAILED!  Calibration itteration %d returned %b", itteration, return);
				end
			end
		end
	endtask

	// read/write
	task testReadWrite;
			reg [5:0] address;
			reg [7:0] data;

			reg [15:0] return;
			reg [15:0] dummy;
		begin
			dummy = { 2'b01, 6'b101010, 8'b0 };
			address = 0;

			repeat (28) begin
				data = llLib.RANDRANGE (255, 0); // generate random data
				
				SPI_TRANSACTION ({ 2'b10, address, data }, return); // write to address, return X

				SPI_TRANSACTION ({ 2'b11, address, 8'b0 }, return); // read from address, return X

				SPI_TRANSACTION (dummy, return); // dummy, return written value

				// assert (write return)
				if (return != { {8{1'b1}}, data }) begin
					
					$display ("!TEST FAILED!  Address %d write returned incorrect value %b", address, return);
				end

				SPI_TRANSACTION (dummy, return); // dummy, return read value;

				// assert (read return: ram)
				if (address >= 0 && address <= 17) begin
					if (return != { 8'b0, data }) begin
						
						$display("!TEST FAILED!  RAM %d read returned incorrect value %b", address, return);
					end

					if (address == 17) address = 40;
					else address = address + 1;
				end

				// else assert (read return: rom intan)
				else if (address >= 40 && address <= 44) begin
					if (address == 40 && return != { 8'b0, "I" }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					else if (address == 41 && return != { 8'b0, "N" }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end
					
					else if (address == 42 && return != { 8'b0, "T" }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					else if (address == 43 && return != { 8'b0, "A" }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					else if (address == 44 && return != { 8'b0, "N" }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					if (address == 44) address = 60;
					else address = address + 1;
				end

				// else assert (read return: rom remainder)
				else if (address >= 60 && address <= 63) begin
					if (address == 60 && return != { 8'b0, REVISION[7:0] }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					else if (address == 61 && return != { 8'b0, UNIPOLAR[7:0] }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end
					
					else if (address == 62 && return != { 8'b0, CHANNELS[7:0] }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					else if (address == 63 && return != { 8'b0, ID[7:0] }) begin
						$display("!TEST FAILED!  ROM %d read returned incorrect value %b", address, return);
					end

					address = address + 1;
				end
			end
		end
	endtask
	
	
	////// initialization //////
	reg [7:0] t = 16'd0;
	initial begin

		// iverilog boilerplate
		$dumpfile("test.vcd");
		$dumpvars(0, rhd2000_dm_tb); // tb module name

		// controls
		nCs <= 1;
		mosi <= 0;
		sclk <= 0;

		// generate tags for each adc channel
		// channel 0 will contain data 16'd1, 1 -> 16'd2, etc...
		t = 16'd0;
		repeat (33) begin
			analog[(t - 1) * 16 +: 16] <= t;
			#1;
			t = t + 16'd1;
			#1;
		end
	end
	

	////// Main //////
	always begin
		$display("#--- STARTING ---# Testbench for Intan RHD2000 Data Model...");

		#`STARTDELAY;
		
		testConvert;

		testCalibration;

		testReadWrite;

		$display("#--- FINISHED ---# RHD2000 Data Model.");
		$finish;
	end

endmodule