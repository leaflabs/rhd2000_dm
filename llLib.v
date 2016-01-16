/*	
	Copyright (c) 2015 LeafLabs LLC
	Author: Charlie Lamantia
	Date: December 2015

	General functions, tasks, and defines for use in
	verilog hdl projects.
*/

`ifndef __LL_LIB__
`define __LL_LIB__

`timescale 1 ps / 1 ps

`define PI 3.1415926535

module llLib();
	
	// generate a sin value
	function real SIN;
		input real 		f; // frequency (MHz)
		input integer 	nBits;

		integer	A;
		real 	t;
		begin
			A = 2 ** nBits;
			t = $realtime / 1000000000.0;

			SIN = A * $sin(t * 2 * `PI * f * 1000000.0);;
		end
	endfunction

	// generate a random integer within a range
	function integer RANDRANGE;
        input integer max;
        input integer min;

        begin
            RANDRANGE = ($unsigned($random) % (max - min)) + min;
        end
    endfunction

endmodule

`endif // __LL_LIB__
