// Filename: fan_timer.v
// Modules: fan_timer
// Authors: Original upstream authors (preserved below); project contributors for local changes.
// Date: 2026-10-13
// General Description: Provides management timer events, including project-local timing configuration.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
// AI disclosure applies only to project-local modifications.

module fan_timer ( 
input RESET_N,
input CLK     , // 400KHz
output reg TIME_OUT=0
);

reg [31:0] DELAY =0;  // 20 bit is enough
always @( negedge RESET_N or posedge  CLK ) 
if (!RESET_N) begin 
    TIME_OUT <=0;
	 DELAY    <=0; 
end
else begin 
         //if (DELAY < 400000/5) DELAY<=DELAY+1;  ///400KHz, about 0.2 second
			if (DELAY < 400000/2) DELAY<=DELAY+1;  ///400KHz, about 0.5 second
	  else 
	   begin 
		 TIME_OUT  <= 1; 
		 DELAY     <= DELAY; 
		end  //delay0.2s
end 
endmodule 


