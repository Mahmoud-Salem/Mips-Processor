module main(clk , instruction , instructionAddress , data , dataAddress , writeEnable);
	input clk;
	input writeEnable ;
	input [6:0] instructionAddress ;
	input [6:0] dataAddress ;
	input [31:0] instruction ;
	input [31:0] data ;
	
	//program counter
	reg [31:0] pc;
	
	//fetch reg
	reg [31:0] fetchDecode_PC;
	reg [31:0] fetchDecode_instruction;
	//comment
	
	//decode reg
	reg  [31:0] decodeExecute_PC;
	reg  [31:0] decodeExecute_readData1;
	reg  [31:0] decodeExecute_readData2;
	reg  [31:0] decodeExecute_signExtend;
	reg  [4:0] decodeExecute_rt;
	reg  [4:0] decodeExecute_rd;//write register
	reg  [4:0] decodeExecute_rs; //rs for forwarding
	reg  [1:0] decodeExecute_wb;//reqWrite memToReg
	reg  [3:0] decodeExecute_mem;//memRead memWrite branch branchNotEqual
	reg  [4:0] decodeExecute_ex;//ALUSrc regDest ALUOp(3 bits)
	
	//execute reg
	reg [31:0] executeMemory_branchAddress;
	reg executeMemory_zf;
	reg [31:0] executeMemory_aluOut;
	reg [31:0] executeMemory_regToMem;
	reg [4:0] executeMemory_rd;//write register
	reg [1:0] executeMemory_wb;//reqWrite memToReg
	reg [3:0] executeMemory_mem;//memRead memWrite branch branchNotEqual
	
	//memory reg
	reg  [31:0] memoryWriteBack_aluOut;
	reg  [31:0] memoryWriteBack_memOut;
	reg  [4:0] memoryWriteBack_rd;//write register
	reg  [1:0] memoryWriteBack_wb;//regWrite memToReg   0  MemtoReg  / 1 RegWrite 
	
	//instruction memory
	reg  [31:0] instructionMemory[127:0];
	
	//data memory
	reg  [31:0] dataMemory [127:0];
	
	//ALU
	wire [31:0] out; //ALUOut
	wire zeroFlag;
	reg [2:0] ALUOP ;

	//Control signals
	reg pcSrc;
	reg branch; 
	reg branchNotEqual;
	reg RegDst;
	reg MemRead;
	reg MemToReg;
	reg MemWrite;
	reg ALUsrc;
	reg RegWrite;
	
	//Counter
	integer i;
	
	
	//Register file
	wire [31:0] readData1, readData2;	

	// forwarding conditions
	reg execCondA;
	reg memCondA;
	reg execCondB;
	reg memCondB;
	
	// TestBench /////////////////
	always @(posedge writeEnable)
	begin
		instructionMemory[instructionAddress] = instruction ;
		dataMemory [dataAddress] = data ;
		pc <=0 ;
	end
	//////////////////
	
	
	///////// loop for printing the output
	always @(posedge clk)
		begin
			$display("Start of cycle");
			#20	$monitor(" memoryWriteBack_aluOut = %b\n memoryWriteBack_memOut = %b\n memoryWriteBack_rd = %b\n memoryWriteBack_wb = %b\n",memoryWriteBack_aluOut,memoryWriteBack_memOut, memoryWriteBack_rd,memoryWriteBack_wb);
			#30	$monitor(" executeMemory_branchAddress = %b\n executeMemory_zf = %b\n executeMemory_aluOut = %b\n executeMemory_regToMem = %b\n executeMemory_rd = %b\n executeMemory_wb = %b\n executeMemory_mem = %b\n",executeMemory_branchAddress,executeMemory_zf,executeMemory_aluOut, executeMemory_regToMem,executeMemory_rd,executeMemory_wb,executeMemory_mem);
			#30 $monitor(" decodeExecute_PC = %b\n decodeExecute_signExtend = %b\n decodeExecute_rt = %b\n decodeExecute_rd = %b\n decodeExecute_wb = %b\n decodeExecute_mem = %b\n decodeExecute_ex = %b\n",decodeExecute_PC,decodeExecute_signExtend,decodeExecute_rt, decodeExecute_rd,decodeExecute_wb,decodeExecute_mem,decodeExecute_ex);
			#15	$monitor(" fetchDecode_PC = %b\n fetchDecode_instruction = %b\n",fetchDecode_PC,fetchDecode_instruction);
			#10 $display("End of cycle\n");

			
		end
	
	
	//modules used
	ALU aluCircuit(clk,out,zeroFlag,decodeExecute_readData1,(decodeExecute_ex[0])?decodeExecute_signExtend:decodeExecute_readData2,decodeExecute_ex[4:2],decodeExecute_signExtend[10:6]);
	registerFile registers(clk ,fetchDecode_instruction [25:21],  fetchDecode_instruction[20:16], memoryWriteBack_rd,(memoryWriteBack_wb [0])? memoryWriteBack_memOut:memoryWriteBack_aluOut, memoryWriteBack_wb[1], readData1, readData2);
	
	
	//Fetch stage
	always @(posedge clk)
		#90
		begin
			fetchDecode_instruction <= instructionMemory[pc] ;
			fetchDecode_PC <= pc+1 ;
			pcSrc = (executeMemory_zf & executeMemory_mem[2])||((!executeMemory_zf) & executeMemory_mem[3]);
			if(pcSrc ==1'b1)
				pc <= executeMemory_branchAddress; 	
			else  
				pc <= pc+1 ;		

		end
	 
	//Decode stage
	always @(posedge clk)
		#75
		begin
			
			if(fetchDecode_instruction[31:26] == 6'b0)// R type
				begin
					branch = 0; 
					branchNotEqual <= 0;
					RegDst = 1;
					MemRead = 0;
					MemToReg = 0;
					MemWrite = 0;
					ALUsrc = 0;
					RegWrite = 1;
					case(fetchDecode_instruction[5:0])
						6'h20 : ALUOP <= 0 ;  //add
						6'h22 : ALUOP <= 1 ;//SUB
						6'h0 : ALUOP <= 4 ; // SLL	
						6'h2 : ALUOP  <= 5 ;//SRL	
						6'h24 : ALUOP <= 2 ;// AND		
						6'h25 : ALUOP <= 3 ; // OR		
						6'h2A : ALUOP <= 7 ;// SLT	
					endcase
				end
			else if (fetchDecode_instruction[31:26] == 6'h23) //LW
				begin
					branch <= 0; 
					branchNotEqual <= 0;
					RegDst <= 0;
					MemRead <= 1;
					MemToReg<= 1;
					MemWrite <=0;
					ALUsrc <=1;
					RegWrite <= 1;	
					ALUOP <= 0 ;
				end
			else if(fetchDecode_instruction[31:26] == 6'h2B) //SW
				begin
					branch <= 0;
					branchNotEqual <= 0;
					RegDst <= 0;
					MemRead <= 0;
					MemToReg<= 0;
					MemWrite <=1;
					ALUsrc <=1;
					RegWrite <= 0;		
					ALUOP <= 0 ;
				end
			else if(fetchDecode_instruction[31:26] == 6'h8) // ADDI
				begin
					branch = 0; 
					branchNotEqual <= 0;
					RegDst = 0;
					MemRead = 0;
					MemToReg = 0;
					MemWrite =0;
					ALUsrc =1;
					RegWrite = 1;		
					ALUOP = 0 ;
				end
			else if(fetchDecode_instruction[31:26] == 6'hD) // ORI
				begin
					branch <= 0;
					branchNotEqual <= 0;
					RegDst <= 0;
					MemRead <= 0;
					MemToReg<= 0;
					MemWrite <=0;
					ALUsrc <=1;
					RegWrite <= 1;		
					ALUOP <= 3 ;
				end
			else if(fetchDecode_instruction[31:26] == 6'hC) // ANDI
				begin
					branch <= 0;
					branchNotEqual <= 0;					
					RegDst <= 0;
					MemRead <= 0;
					MemToReg<= 0;
					MemWrite <=0;
					ALUsrc <=1;
					RegWrite <= 1;		
					ALUOP <= 2 ;
				end
				
			else if(fetchDecode_instruction[31:26] == 6'h4) // BEQ
				begin
					branch <= 1; 
					branchNotEqual <= 0;
					RegDst <= 0;
					MemRead <= 0;
					MemToReg<= 0;
					MemWrite <=0;
					ALUsrc <= 0;
					RegWrite <= 0;	
					ALUOP <= 0 ;
				end
			else if(fetchDecode_instruction[31:26] == 6'h5) //BNE
				begin
					branch <=0;
					branchNotEqual <= 1;
					RegDst <= 0;
					MemRead <= 0;
					MemToReg<= 0;
					MemWrite <=0;
					ALUsrc <=0;
					RegWrite <= 0;
					ALUOP <= 0 ;
				end
				
			#5		//// add delay here  
			decodeExecute_PC = fetchDecode_PC;
			decodeExecute_signExtend = {{16{fetchDecode_instruction[15]}},fetchDecode_instruction[15:0]};
			decodeExecute_rs = fetchDecode_instruction[25:21]; //forwarding
			decodeExecute_rt = fetchDecode_instruction[20:16];
			decodeExecute_rd = fetchDecode_instruction[15:11];
			decodeExecute_wb[0] = MemToReg ;
			decodeExecute_wb[1] = RegWrite ;
			decodeExecute_mem[0] = MemRead;
			decodeExecute_mem[1] = MemWrite;
			decodeExecute_mem[2] = branch;
			decodeExecute_mem[3] = branchNotEqual;
			decodeExecute_ex[0] = ALUsrc ;
			decodeExecute_ex[1] = RegDst;
			decodeExecute_ex[4:2] = ALUOP;
				
				
			///no forwarding`
			decodeExecute_readData1 = readData1; //rs
			decodeExecute_readData2 = readData2; //rt
				
			///forwarding
			
			//ALU
			execCondA = (executeMemory_rd == decodeExecute_rs && executeMemory_wb[1]&&(executeMemory_rd !=0));
			execCondB = (executeMemory_rd == decodeExecute_rt &&  executeMemory_wb[1]&&(executeMemory_rd !=0));
			// MEM
			memCondA = (memoryWriteBack_rd == decodeExecute_rs &&  memoryWriteBack_wb[1]&&(memoryWriteBack_rd !=0)&& !execCondA);
			memCondB = (memoryWriteBack_rd == decodeExecute_rt && memoryWriteBack_wb[1]&&(memoryWriteBack_rd !=0) && !execCondB);
			//forwardA
			if(execCondA)
				decodeExecute_readData1= executeMemory_aluOut;
			if(memCondA)
				decodeExecute_readData1= (memoryWriteBack_wb [0])? memoryWriteBack_memOut:memoryWriteBack_aluOut;
			//forwardB
			if(execCondB)
				decodeExecute_readData2 = executeMemory_aluOut;
			if(memCondB)
				decodeExecute_readData2 = (memoryWriteBack_wb [0])? memoryWriteBack_memOut:memoryWriteBack_aluOut;
		
		end

	
	//Execute stage
	always @(posedge clk)
		#50
		begin
			executeMemory_branchAddress = decodeExecute_PC + decodeExecute_signExtend ;//*4;
			executeMemory_zf = zeroFlag;
			executeMemory_aluOut = out;
			executeMemory_regToMem = decodeExecute_readData2;
			executeMemory_rd = (decodeExecute_ex[1])?decodeExecute_rd:decodeExecute_rt;
			executeMemory_wb = decodeExecute_wb;
			executeMemory_mem = decodeExecute_mem;
		
		end
	
	//Memory stage
	always @(posedge clk)
		#20
		begin
			memoryWriteBack_aluOut = executeMemory_aluOut;
			if(executeMemory_mem[0])
				memoryWriteBack_memOut = dataMemory[executeMemory_aluOut];
			else
				memoryWriteBack_memOut = 0;
			if(executeMemory_mem[1])
				dataMemory[executeMemory_aluOut] = executeMemory_regToMem; 
			memoryWriteBack_rd = executeMemory_rd;
			memoryWriteBack_wb = executeMemory_wb;
		
		end
		
	initial
		begin
			#5350
			for(i = 0 ; i < 32 ; i = i + 1)
				begin
					$display("Value in memory at address %d = %d",i,dataMemory[i]);
				end
		end
	
endmodule