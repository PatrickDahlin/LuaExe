local dbg = require("debugger")
local module = {}


--[[

	Notes:

		- aggregating unary '-' operator should collapse to a '--' unary op
			this can be repeated many times which isn't handled here

]]

local function setup_stack(IR)
	local stack = {}

	stack.variables = {}
	stack.ptr = 0

	stack.pop_destroyed = function()
		if #stack.variables > 0 and
			stack.variables[#stack.variables].destroyed then
			
			local ins = {}
			ins.type = "dealloc"
			ins.size = stack.variables[#stack.variables].size or 0
			table.insert(IR.code, ins)
			table.remove(stack.variables)
			stack.ptr = stack.ptr - ins.size
			stack.pop_destroyed()
		end 
	end

	stack.alloc = function(s, t)
		local var = {
			tag = t,
			size = s,
			destroyed = false
		}
		stack.pop_destroyed()
		table.insert(stack.variables, var)
		local ins = {}
		ins.type = "alloc"
		ins.size = s
		stack.ptr = stack.ptr + s
		
		table.insert(IR.code, ins)
		return "[rsp-?]"
	end

	stack.dealloc = function(tag)
		stack.variables[tag].destroyed = true
	end

	IR.stack = stack
	return stack
end

local function ir_mov(IR, to, from)
	local ins = {}
	ins.type = "MOV"
	ins.reg1 = to
	ins.reg2 = from
	table.insert(IR.code, ins)
end

local function ir_div(IR)
	local ins = {}
	ins.type = "DIV"
	ins.reg1 = "r10"
	ins.reg2 = "r11"
	table.insert(IR.code, ins)
end

local function ir_mul(IR)
	local ins = {}
	ins.type = "MUL"
	ins.reg1 = "r10"
	ins.reg2 = "r11"
	table.insert(IR.code, ins)
end

local function ir_sub(IR)
	local ins = {}
	ins.type = "SUB"
	ins.reg1 = "r10"
	ins.reg2 = "r11"
	table.insert(IR.code, ins)
end

local function ir_add(IR)
	local ins = {}
	ins.type = "ADD"
	ins.reg1 = "r10"
	ins.reg2 = "r11"
	table.insert(IR.code, ins)
end

local function parse_un(IR, node)
	return node.op .. tostring(node.right.value)
end

local function parse_bin(IR, node)
	if node == nil then return "err" end
	local op_node = node

	local left, right

	if node.left.type == "number" then
		left = tostring(node.left.value)
	end
	if node.right.type == "number" then
		right = tostring(node.right.value)
	end

	if node.left.type == "identifier" then
		left = node.left.name
	end
	if node.right.type == "identifier" then
		right = node.right.name
	end

	if left == nil and node.left.type == "operator" then
		if node.left.op_type == "binary" then
			left = parse_bin(IR, node.left)
		elseif node.left.op_type == "unary" then
			left = parse_un(IR, node.left)
		end
	end
	if right == nil and node.right.type == "operator" then
		if node.right.op_type == "binary" then
			right = parse_bin(IR, node.right)
		elseif node.right.op_type == "unary" then
			right = parse_un(IR, node.right)
		end
	end

	-- This may break if unary statement on either side but will do for now
	if left == nil and node.left.type == "exp" then
		left = parse_bin(IR, node.left.exp)
	end
	if right == nil and node.right.type == "exp" then
		right = parse_bin(IR, node.right.exp)
	end
	

	local op_list = {
		["+"] = ir_add,
		["-"] = ir_sub,
		["*"] = ir_mul,
		["/"] = ir_div
	}

	ir_mov(IR, "r10", left)
	ir_mov(IR, "r11", right)
	op_list[op_node.op](IR)
	local result = IR.stack.alloc(64)
	ir_mov(IR, result, "r10")

	return result
end

local function parse_assign(IR, node)
	local assign_node = node
	node = node.right
	if node == nil then error("A") end

	local alloc = false
	local result_addr
	if node.type == "operator" and node.op_type == "binary" then
		result_addr = parse_bin(IR, node)
	elseif node.type == "operator" and node.op_type == "unary" then
		result_addr = parse_un(IR, node)
	elseif node.type == "number" then
		result_addr = tostring(node.value)
		alloc = true
	elseif node.type == "identifier" then
		result_addr = tostring(node.name)
		alloc = true
	end
	
	-- Allocate output
	if alloc then
		local addr = IR.stack.alloc(64, assign_node.name)
		ir_mov(IR, addr, result_addr)
		result_addr = addr
	end

	-- Result is on the stack at result_addr
end

local function IR_parse(IR, AST)

	local stack = setup_stack(IR)

	for k, v in pairs(AST.nodes) do
		if v.type == "operator" and v.op == "=" then
			parse_assign(IR, v)
		end
	end

end


module.translate = function(AST)
	
	local IR = {}
	IR.code = {} -- Output that is assembled later on

	IR_parse(IR, AST)

	return IR

end

return module