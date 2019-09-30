--[[
	Syntax checker for AST built by parser
]]
local module = {}
local dbg = require("debugger")
dbg.auto_where = 3
local error = require("error")
local err = error.err
local assert = error.assert
-- Helper functions



local function cond_assert(e, v, n, msg)
	if not e then return end
	assert(v, n, msg)
end

local function is_node(n, allow_error)
	local val = n ~= nil and n.type ~= nil
	cond_assert(allow_error, val, n, "Type is not a node")
	return val
end

local function is_op(n, allow_error)
	local val = is_node(n, allow_error) and n.type == "operator" and n.op_type ~= nil
	cond_assert(allow_error, val, n, "Expected an operator")
	return val
end

local function is_un_op(n, allow_error)
	local val = is_op(n, allow_error) and
				(n.op_type == "unary" or 
				n.op_type == "either")
	cond_assert(allow_error, val, n, "Expected unary operator")
	return val
end

local function is_ident(n, allow_error)
	local val = is_node(n, allow_error) and n.type == "identifier" and n.name ~= nil
	cond_assert(allow_error, val, n, "Expected identifier")
	return val
end

local function is_num(n, allow_error)
	local val = is_node(n, allow_error) and n.type == "number" and n.value ~= nil
	cond_assert(allow_error, val, n, "Expected number")
	return val
end

local function is_terminal(n, allow_error)
	local val = is_num(n, false) or is_ident(n, false)
	cond_assert(allow_error, val, n, "Expected either number or identifier")
	return val
end

local function is_exp(n, allow_error)
	cond_assert(allow_error, is_node(n), n, "Expected expression")
	local exp = false
	local terminal = false
	local binary = false
	local unary = false
	
	if is_node(n) then
		exp = (n.type == "exp" and is_exp(n.exp, allow_error))
		terminal = is_terminal(n, false)

		-- Exclude unary operator and assignment statement
		binary = is_op(n, false) and n.op_type ~= "unary"
		binary = binary and n.op ~= "="
		if binary and n.left == nil then binary = false end

		unary = is_op(n, false) and n.op_type ~= "binary"
		if unary then
			cond_assert(allow_error, n.right ~= nil and is_exp(n.right, allow_error), n,
					"Expected right side operand of operator '"..tostring(n.op).."'")
			unary = unary and n.right ~= nil and is_exp(n.right, allow_error)
			if unary then n.op_type = "unary" end
		end
		if binary then
			cond_assert(allow_error, n.left ~= nil and is_exp(n.left, allow_error), n,
					"Expected left side operand of operator '"..tostring(n.op).."'")
				binary = binary and n.left ~= nil and is_exp(n.left, allow_error)

			cond_assert(allow_error, n.right ~= nil and is_exp(n.right, allow_error), n,
					"Expected right side operand of operator '"..tostring(n.op).."'")
			binary = binary and n.right ~= nil and is_exp(n.right, allow_error)
			if binary and n.op_type ~= "binary" then n.op_type = "binary" end
		end
		
	end

	cond_assert(allow_error, exp or terminal or binary or unary, n, "Expected expression")

	return exp or terminal or binary or unary
end

local function is_bin_op(n, allow_error)
	local val = is_op(n, allow_error)
	
	cond_assert(allow_error, val, n, "Expected operator")
	if n.op_type == "binary" then
		cond_assert(allow_error, n.left ~= nil, n, "Expected left side operand of binary operator")
		cond_assert(allow_error, n.right ~= nil, n, "Expected right side operand of binary operator")
		val = val and is_exp(n.left, allow_error)
		val = val and is_exp(n.right, allow_error)
	elseif n.op_type == "either" then
		cond_assert(allow_error, n.right ~= nil, n, "Expected right side expression of unary operator")
		val = val and is_exp(n.right, allow_error)
	else
		err(n)
	end
	return val
end



local rules = {}

local function add_rule(rule_name, verification_func)
	local rule = {
		name = rule_name,
		verify = verification_func
	}
	table.insert(rules, rule)
end


local function verify_op(node, type, symbol, allow_error)
	local is_bin = node.type == "operator" and 
			node.op_type == type and 
			node.op == symbol

	cond_assert(allow_error, is_bin, node, "Expected binary expression")
	if type == "binary" then
		is_bin = is_bin and is_bin_op(node, true)
	end
	return is_bin
end

local function assign_verification(node)
	-- Verify node contents to match assignment statement
	-- Return false otherwise
	local v = true
	v = v and verify_op(node, "binary", "=", false)
	assert(v, node, "Expected assignment statement")
	--if not v then print("Not a binary operator") end
	v = v and is_ident(node.left, true)
	--if not v then print("Not an identifier") end
	v = v and is_exp(node.right, true)
	--if not v then print("No expression") end


	return v
end

add_rule("assignment",
			assign_verification)

module.verify = function(ast)
	for k,v in pairs(ast.nodes) do
		if not assign_verification(v) then
			return false
		end
	end
	return true
end

return module