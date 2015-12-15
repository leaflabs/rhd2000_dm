/*	
	Copyright (c) 2015 LeafLabs LLC
	Author: Charlie Lamantia
	Date: December 2015

	General functions, tasks, and defines for use in
	verilog hdl projects.
*/

`ifndef __LL_LIB__
`define __LL_LIB__

module llLib();

	// generate a random integer within a range
	function [31:0] RANDRANGE;
        input [31:0] max;
        input [31:0] min;

        begin
            RANDRANGE = ($unsigned($random) % (max - min)) + min;
        end
    endfunction

endmodule

`endif
