////////////////////////////////////////////////////////////////////////////////
// Filename:    clk.v
// Author:      T. Martin
// Date:        09/07/04
// Version:     2
// Description: This module functions as a simple behavioral circuit that
//              SIMULATES a free-running clock. DO NOT USE THIS MODULE AS A 
//              TEMPLATE FOR A SYNTHESIZABLE CLOCK!
//
//              This module has one input:
//              - enable_i:  The clock module runs when this is asserted.
//
//              This module has one output:
//	        - clk_out_o: The clock output.
// 
// 		This module has one parameter:
//              - period: The clock period of the free-running output (in ns).
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 09/07/2004  TLM  1        Original
// 08/24/2005  PMA  2        Restructured for Fall 2005
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns

module clk(enable_i, clk_out_o);
   input  enable_i;		// enable_i allows clk_out_o to "run" when asserted.
   output clk_out_o;		// enable_i-controlled clock output.
   reg    clk_out_o;		// variable clk_out_o is defined procedurally.

   parameter PERIOD = 50;	// The default period of the clock.

// Set initial value for clk_out_o on power-up
   initial
      clk_out_o = 0;

// Produce controlled free-running clock
   always begin
      #(PERIOD/2);
      if(enable_i)
         clk_out_o = ~clk_out_o;
   end

endmodule
