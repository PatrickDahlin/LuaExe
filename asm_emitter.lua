local module = {}

--[[

	When allocating push stack marker
	which is assigned to the variable

	If the variable is needed then just
	calculate the diff between the var
	marker and current stack marker
	which will be the offset for rsp



	!!
	THIS IS JUST AN EXPERIMENT IN HOW TO HANDLE OUTPUT
	!!

]]



local instru = {
	["alloc8"]  = {asm="sub rsp, 8",  type="alloc", size=8},
	["alloc16"] = {asm="sub rsp, 16", type="alloc", size=16},
	["alloc32"] = {asm="sub rsp, 32", type="alloc", size=32},
	["alloc64"] = {asm="sub rsp, 64", type="alloc", size=64}
}

local function init_IR()
	local tmp = {}
	tmp.stack_pointer = 0
	tmp.instructions = {}
	return tmp
end

local function alloc_stack(IR, size, note)
	local emit = {}
	emit.asm = instru[size].asm
	emit.type = instru[size].type
	emit.size = instru[size].size	
--	local emit = instru[size]
	if note ~= nil then 
		emit.asm = emit.asm .. "; "..tostring(note)
	end

	table.insert(IR.instructions, emit)
	IR.stack_pointer = IR.stack_pointer + instru[size].size
	return IR.stack_pointer
end

local function alloc_stack_int64(IR,variable)
	local stack_addr = alloc_stack(IR, "alloc64", "int64")
	variable.address = stack_addr
	return stack_addr
end

local function emit_instructions(f, IR)
	for k,v in pairs(IR.instructions) do
		f:write("	")
		f:write(v.asm)
		f:write("\n")
	end
end

local function emit_header(f)
	f:write("extern printf\n")
	f:write("extern ExitProcess\n")
	f:write("; END OF HEADER\n")
	f:write("section .text\n")
	f:write("	global main\n")
	f:write("main:\n")
	f:write("	mov rdx, -1\n")
end

local function emit_footer(f)
	f:write("	mov rcx, msg\n")
	f:write("	call printf\n")
	f:write("	xor ecx,ecx\n")
	f:write("	call ExitProcess\n")
	f:write("section .data\n")
	f:write("msg db \"End of program %i\",0\n")
	f:write("section .bss\n")
end

local function emit_IR(IR)
	local f = io.open("build.asm", "w")
	emit_header(f)
	emit_instructions(f, IR)
	emit_footer(f)
	f:close()
end


local function emit_assign(IR, s, var)
	
	-- mov
	local instruction = {}
	instruction.asm = "mov rdx, qword "
	instruction.asm = instruction.asm .. tostring(s.right.value)
	table.insert(IR.instructions, instruction)
	
	instruction = {}
	instruction.asm = "mov [rsp-"
	instruction.asm = instruction.asm .. tostring(IR.stack_pointer - var.address)
	instruction.asm = instruction.asm .. "], rdx"

	table.insert(IR.instructions, instruction)
end

module.compile = function(ast, outname)
	-- ast.nodes contains all statements
	-- ast.variables for all variables used
	-- ast.constants for all constant values (currently only numbers)

	-- step through all statements
	-- for each one, break them down to single operations
	-- output said operations as assembly

	local IR = init_IR()

	local vars = {}

	for v in pairs(ast.variables) do
		local tmp = {}
		tmp.name = v
		tmp.address = "nil"
		alloc_stack_int64(IR, tmp)
		vars[v] = tmp
	end

	for k,s in pairs(ast.nodes) do
		if s.type == "operator" and s.op_type == "binary" and s.op == "=" then
			emit_assign(IR, s, vars[s.left.name])
		end
	end

	emit_IR(IR)
end

return module