local dbg = require("debugger")
local error = require("error")
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
	stack.alloc_index = 0

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
			index = stack.alloc_index +1,
			tag = t,
			size = s,
			offset = 0,
			destroyed = false
		}
		stack.pop_destroyed()
		stack.alloc_index = stack.alloc_index + 1
		table.insert(stack.variables, var)
		local ins = {}
		ins.type = "alloc"
		ins.size = s
		ins.tag = t
		ins.cmt = "stack alloc for "..(t or "")
		stack.ptr = stack.ptr + s
		
		table.insert(IR.code, ins)
		return stack.alloc_index
	end

	stack.dealloc = function(tag)
		stack.variables[tag].destroyed = true
	end

	stack.has_tag = function(tag)
		for k,v in pairs(stack.variables) do
			if v.tag == tag then return true end
		end
		return false
	end

	stack.get_tag = function(tag)
		for k,v in pairs(stack.variables) do
			if v.tag == tag then return v end
		end
		return nil
	end

	stack.calc_rsp = function(index)
		if index > stack.alloc_index then return -1 end
		local offset = 0

		for i=#stack.variables, 1, -1 do
			if stack.variables[i].index == index then break end
			offset = offset + stack.variables[i].size
		end
		return "qword [rsp+"..offset.."]"
	end

	IR.stack = stack
	return stack
end

-- Moves contents of register 2 into register 1
local function ir_mov(IR, to, from, cmt)
	local ins = {}
	ins.type = "MOV"
	ins.reg1 = to
	ins.reg2 = from
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

-- Gets the effective address from register2 and stores that in register 1
local function ir_lea(IR, to, from, cmt)
	local ins = {}
	ins.type = "LEA"
	ins.reg1 = to
	ins.reg2 = from
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

-- Integer division with "rax" where answer is stored in rax
local function ir_div(IR, cmt)
	local ins = {}
	ins.type = "DIV"
	ins.reg1 = "r10"
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

-- Multiply rax with r10 and store answer in rax
local function ir_mul(IR, cmt)
	local ins = {}
	ins.type = "MUL"
	ins.reg1 = "r10"
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

-- Subtract rax and r10 and store result in rax
local function ir_sub(IR, cmt)
	local ins = {}
	ins.type = "SUB"
	ins.reg1 = "rax"
	ins.reg2 = "r10"
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

-- Add rax and r10 and store in rax
local function ir_add(IR, cmt)
	local ins = {}
	ins.type = "ADD"
	ins.reg1 = "rax"
	ins.reg2 = "r10"
	ins.cmt = cmt
	table.insert(IR.code, ins)
end

local function ir_neg(IR, n)
	local ins = {}
	ins.type = "NEG"
	ins.reg1 = n
	table.insert(IR.code, ins)
end

local function parse_un(IR, node)
	
	local num
	if node.right.type == "exp" then
		num = parse_bin(IR, node.right.exp)
		ir_mov(IR, "rax", IR.stack.calc_rsp(num))
	elseif node.right.type == "identifier" then
		num = IR.stack.get_tag(node.right.name)
		num = num.index
		ir_mov(IR, "rax", IR.stack.calc_rsp(num))
	elseif node.right.type == "number" then
		num = IR.stack.alloc(64)
		ir_mov(IR, "rax", node.right.value)
	end

	ir_neg(IR, "rax")
	ir_mov(IR, IR.stack.calc_rsp(num), "rax")
	return num
end

local function parse_bin(IR, node)
	if node == nil then return "err" end
	local op_node = node

	local left, right
	local is_l_index = true
	local is_r_index = true

	if node.left ~= nil and node.left.type == "number" then
		left = tostring(node.left.value)
		is_l_index = false
	end
	if node.right.type == "number" then
		right = tostring(node.right.value)
		is_r_index = false
	end

	if node.left ~= nil and node.left.type == "identifier" then
		left = IR.stack.get_tag(node.left.name)
		error.assert(left ~= nil,
					node.left,
					"Use of undeclared variable '"..node.left.name.."'")
		left = left.index
	end
	if node.right.type == "identifier" then
		right = IR.stack.get_tag(node.right.name)
		error.assert(right ~= nil, 
					node.right, 
					"Use of undeclared variable '"..node.right.name.."'")
		right = right.index
	end

	if left == nil and node.left ~= nil and node.left.type == "operator" then
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
	if left == nil and node.left ~= nil and node.left.type == "exp" then
		local exp = node.left.exp
		if exp.type == "operator" and exp.op_type == "binary" then
			left = parse_bin(IR, exp)
		elseif exp.type == "operator" and exp.op_type == "unary" then
			left = parse_un(IR, exp)
		elseif exp.type == "number" then
			left = tonumber(exp.value)
		elseif exp.type == "identifier" then
			left = IR.stack.get_tag(exp.name)
			error.assert(left ~= nil,
							exp,
							"Use of undeclared variable '"..exp.name.."'")
			left = left.index
		end
	end
	if right == nil and node.right.type == "exp" then
		local exp = node.right.exp
		if exp.type == "operator" and exp.op_type == "binary" then
			right = parse_bin(IR, node.right.exp)
		elseif exp.type == "operator" and exp.op_type == "unary" then
			right = parse_un(IR, exp)
		elseif exp.type == "number" then
			right = tonumber(exp.value)
		elseif exp.type == "identifier" then
			right = IR.stack.get_tag(exp.name)
			error.assert(right ~= nil,
							exp,
							"Use of undeclared variable '"..exp.name.."'")
			right = right.index
		end
	end
	

	local op_list = {
		["+"] = ir_add,
		["-"] = ir_sub,
		["*"] = ir_mul,
		["/"] = ir_div
	}

	if is_l_index then
		left = IR.stack.calc_rsp(left)
	end
	if is_r_index then
		right = IR.stack.calc_rsp(right)
	end

	ir_mov(IR, "rax", left, "Prep a")
	ir_mov(IR, "r10", right, "Prep b")
	op_list[op_node.op](IR, "Perform arith")
	local result = IR.stack.alloc(64)
	ir_mov(IR, IR.stack.calc_rsp(result), "rax", "Result into stack")

	return result
end

local function parse_assign(IR, node)
	local assign_node = node
	node = node.right

	local addr = IR.stack.get_tag(assign_node.left.name)
	if addr == nil then
		addr = IR.stack.alloc(64, assign_node.left.name)
	else
		addr = addr.index
	end

	if node == nil then error("huh") end

	local alloc = false
	local result_addr
	if node.type == "operator" and node.op_type == "binary" then
		result_addr = parse_bin(IR, node)
		alloc = true
	elseif node.type == "operator" and node.op_type == "unary" then
		result_addr = parse_un(IR, node)
		alloc = true
	elseif node.type == "number" then

		result_addr = tostring(node.value)
		ir_mov(IR, "rax", result_addr)
		ir_mov(IR, IR.stack.calc_rsp(addr), "rax", "Load immediate to stack")
		result_addr = addr

	elseif node.type == "identifier" then
		result_addr = tostring(node.name)
		local has = IR.stack.has_tag(node.name)
		assert(has)
		result_addr = IR.stack.get_tag(node.name).index
		ir_mov(IR, "rax", IR.stack.calc_rsp(result_addr), "Load var into reg")

		alloc = true
	elseif node.type == "exp" then
		local exp = node.exp
		---TODO
	end
	
	-- Allocate output
	if alloc then
		ir_mov(IR, IR.stack.calc_rsp(addr), "rax", "Store rax temp into stack")
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