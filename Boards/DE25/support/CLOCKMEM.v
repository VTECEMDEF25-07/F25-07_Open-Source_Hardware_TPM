// Filename: CLOCKMEM.v
// Modules: CLOCKMEM
// Authors: Original upstream authors (preserved below); project contributors for local changes.
// Date: 2026-10-13
// General Description: Divides the board clock for management timing, including project-local parameterization.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
// AI disclosure applies only to project-local modifications.



module CLOCKMEM ( 
input                RESET_n, 
input                CLK ,
input [31:0]         CLK_FREQ ,
output reg  			CK_1HZ
) ;

//---50MHZ CLOCK1 TEST---
reg  [31:0] CLK_DELAY ; //important , 64 bit is eeror 

//--
always @(negedge   RESET_n  or posedge CLK )  
if ( !RESET_n  ) begin 
     CK_1HZ    <=0; 
	  CLK_DELAY <=0; 
end 
else 
begin
	if    ( CLK_DELAY  >   CLK_FREQ[31:1] )  begin  CLK_DELAY <=0 ;  CK_1HZ<= ~CK_1HZ ; end 
	else 	 CLK_DELAY  <= CLK_DELAY+1;   
end		
	
endmodule 


	
	