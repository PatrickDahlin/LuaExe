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
		ins.cmt = "alloc "..(t or "").." offset:"..stack.ptr
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

	stack.get_location = function(index)
		if index > stack.alloc_index then return -1 end
		local offset = 0
		for i=1, #stack.variables, 1 do
			if stack.variables[i].index == index then break end
			offset = offset + stack.variables[i].size
		end
		return offset
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

local parse_exp

local function parse_un(IR, node)
	error.assert(node.right ~= nil or node.left ~= nil, node, "Expected unary expression")

	-- Result is what is used for further calculation
	-- thus we should return the "old" value of variable
	-- incase it's postfix, this old value can be stack-allocated temp var

	local num
	ir_mov(IR, "r10", 1)
	if node.right ~= nil then
		if node.right.type == "exp" then
			error.assert(false,node,"Syntax error")
			num = parse_exp(IR, node.right.exp)
			ir_mov(IR, "rax", IR.stack.calc_rsp(num), "move from ["..IR.stack.get_location(num).."]")
		elseif node.right.type == "identifier" then
			num = IR.stack.get_tag(node.right.name)
			error.assert(num ~= nil, node.right, "Undeclared identifier")
			num = num.index
			ir_mov(IR, "rax", IR.stack.calc_rsp(num), "move from ["..IR.stack.get_location(num).."]")
		elseif node.right.type == "number" then
			error.assert(false, node, "Syntax error")
			num = IR.stack.alloc(64)
			ir_mov(IR, "rax", node.right.value)
		end
		if node.op == "--" then ir_sub(IR, "pre--") end
		if node.op == "++" then ir_add(IR, "pre++") end
		-- Result is in rax
		ir_mov(IR, IR.stack.calc_rsp(num), "rax", "move to ["..IR.stack.get_location(num).."]") -- Move result of prefix calc into var "num"
	elseif node.left ~= nil then
		local true_value
		num = IR.stack.alloc(64)
		if node.left.type == "identifier" then
			true_value = IR.stack.get_tag(node.left.name)
			error.assert(true_value ~= nil, node.left, "Undeclared identifier")
			true_value = true_value.index -- we only want the index, overwrite temp with this index
			ir_mov(IR, "rax", IR.stack.calc_rsp(true_value), "move from ["..IR.stack.get_location(true_value).."]") -- get value into rax
			ir_mov(IR, IR.stack.calc_rsp(num), "rax", "move to ["..IR.stack.get_location(num).."]") -- move value into the result before we do add/sub
		else error.assert(false, node, "Syntax error")
		end

		if node.op == "--" then ir_sub(IR, "post--") end
		if node.op == "++" then ir_add(IR, "post++") end
		ir_mov(IR, IR.stack.calc_rsp(true_value), "rax", "move to ["..IR.stack.get_location(true_value).."]") -- Move result of prefix calc into our variable (this doesnt affect the return value)

	end

	return num
end

local parse_bin

parse_exp = function(IR, node)
	if node == nil then return -1 end

	local out_index

	if node.type == "operator" then
		if node.op_type == "binary" then
			out_index = parse_bin(IR, node)
		elseif node.op_type == "unary" then
			out_index = parse_un(IR, node)
		end
	elseif node.type == "identifier" then
		local a = IR.stack.get_tag(node.name)
		error.assert(a ~= nil, node,
						"Use of undeclared variable '"..node.name.."'")
		out_index = a.index
	elseif node.type == "number" then
		out_index = IR.stack.alloc(64)
		ir_mov(IR, IR.stack.calc_rsp(out_index), tostring(node.value))
	elseif node.type == "exp" then
		return parse_exp(IR, node.exp)
	end

	return out_index
end

parse_bin = function(IR, node)
	if node == nil then return "err" end
	local op_node = node

	local left, right

	left = parse_exp(IR, node.left)
	right = parse_exp(IR, node.right)


	local op_list = {
		["+"] = ir_add,
		["-"] = ir_sub,
		["*"] = ir_mul,
		["/"] = ir_div
	}

	local reg1 = "rax"
	local reg2 = "r10"

	ir_mov(IR, reg1, IR.stack.calc_rsp(left), "Prep left from ["..IR.stack.get_location(left).."]")
	ir_mov(IR, reg2, IR.stack.calc_rsp(right), "Prep right from ["..IR.stack.get_location(right).."]")
	op_list[op_node.op](IR, "")
	local result = IR.stack.alloc(64)
	ir_mov(IR, IR.stack.calc_rsp(result), "rax", "Result into ["..IR.stack.get_location(result).."]")

	return result
end


local function parse_assign(IR, node)
	local assign_node = node
	node = node.right


	if node == nil then error("huh") end

	local result = parse_exp(IR, node) -- rax contains result

	local addr = IR.stack.get_tag(assign_node.left.name)
	if addr == nil then
		addr = IR.stack.alloc(64, assign_node.left.name, "var \""..assign_node.left.name.."\"")
	else
		addr = addr.index
	end

	ir_mov(IR, "rax", IR.stack.calc_rsp(result))
	ir_mov(IR, IR.stack.calc_rsp(addr), "rax", "Store into var \""..assign_node.left.name.."\" ["..IR.stack.get_location(addr).."]")
	result_addr = addr

	-- Result is on the stack at result_addr
end

local function parse_unary(IR, node)
	local ident = node.left or node.right
	local addr = IR.stack.get_tag(ident.name)
	if addr == nil then
		addr = IR.stack.alloc(64, ident.name, "var \""..ident.name.."\"")
	else
		addr = addr.index
	end
	ir_mov(IR, "rax", IR.stack.calc_rsp(addr))
	ir_mov(IR, "r10", 1)
	if node.op == "++" then
		ir_add(IR, "unary increment")
	elseif node.op == "--" then
		ir_sub(IR, "unary decrement")
	end
	ir_mov(IR, IR.stack.calc_rsp(addr), "rax")
end

local function IR_parse(IR, AST)

	local stack = setup_stack(IR)

	for k, v in pairs(AST.nodes) do
		if v.type == "operator" and v.op == "=" then
			parse_assign(IR, v)
		elseif v.type == "operator" and v.op_type == "unary" then
			parse_unary(IR, v)
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