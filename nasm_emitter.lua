local dbg = require("debugger")
local IR = require("IR_translator")
local module = {}

local function setup_output(out)
	local o = {}
	o.file = io.open(out..".asm", "w")
	return o
end

local function add_import(out, import)
	out.file:write("extern "..import.."\n")
end

local function emit_data(o)
	o.file:write("section .data\n")
	o.file:write("msg db \"End of program %i\",0\n")
	o.file:write("section .bss\n")
end

local function emit_ir(ir, output)
	local o = function(s) output.file:write(s) end

	local lookup = {
		["MOV"] = "mov ",
		["alloc"] = "sub rsp, ",
		["ADD"] = "add ",
		["SUB"] = "sub ",
		["MUL"] = "mul ",
		["DIV"] = "div "
	}

	for k,v in pairs(ir.code) do
		local ins = lookup[v.type]
		if v.type ~= "alloc" then
			ins = "\t"..ins
			if tonumber(v.reg1) ~= nil then
				ins = ins.."qword "
			end
			ins = ins..v.reg1
			if v.reg2 ~= nil then
				if tonumber(v.reg2) ~= nil then
					ins = ins..", qword "
				else
					ins = ins..", "
				end
				ins = ins..v.reg2
			end
		else
			ins = "\t"..ins.."qword "..v.size
		end
		o(ins.."\t\t;"..(v.cmt or "").."\n")
	end
end

module.emit = function(ir, out)

	local output = setup_output(out)

	add_import(output, "printf")
	add_import(output, "ExitProcess")

	-- write main header
	output.file:write("\nsection .text\n")
	output.file:write("	global main\n")
	output.file:write("main:\n")
	output.file:write("	sub rsp, 32\n") -- shadow space
	output.file:write("	mov rdx, -1\n") -- init rdx to -1

	emit_ir(ir, output)	
	--output.file:write(" sub rsp, 8\n") -- align

	output.file:write("	mov rdx, rax\n")
	-- emit printf
	output.file:write("	mov rcx, msg\n")
	output.file:write("	call printf\n")
	-- emit ExitProcess call
	output.file:write("	xor ecx,ecx\n")
	output.file:write("	call ExitProcess\n")
	emit_data(output)

	output.file:close()

end

return module