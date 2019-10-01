local module = {}

local instru = {
	["alloc8"]  = {asm="sub rsp, 8", size=8},
	["alloc16"] = {asm="sub rsp, 16", size=16},
	["alloc32"] = {asm="sub rsp, 32", size=32},
	["alloc64"] = {asm="sub rsp, 64", size=64}
}

local function init_IR()
	local tmp = {}
	tmp.stack_pointer = 0
	tmp.instructions = {}
	return tmp
end

local function alloc_stack(IR, size, note)
	local addr = IR.stack_pointer
	local emit = instru[size].asm
	if note ~= nil then 
		emit = emit .. "; "..tostring(note)
	end

	table.insert(IR.instructions, emit)
	IR.stack_pointer = IR.stack_pointer + instru[size].size
	return addr
end

local function alloc_stack_int64(IR,variable)
	local stack_addr = alloc_stack(IR, "alloc64", "int64")
	variable.address = stack_addr
	return stack_addr
end

local function emit_instructions(f, IR)
	for k,v in pairs(IR.instructions) do
		f:write("	")
		f:write(v)
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
	end

	emit_IR(IR)
end

return module