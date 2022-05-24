--[[
	Parser for tokenizer
]]
local module = {}
local write = io.write
local error = require("error")
local err = error.err
local assert = error.assert
local dbg = require("debugger")

local function myassert(val, tok, msg)
	if val ~= nil and val and tok ~= nil then return end
	error("Error in file "..tostring(tok:get_file())..":"..
			tostring(tok:get_line()).."  -  "..tostring(msg))
end

local function create_node(tok, token, node_type)
	local node = {
		type = node_type or token.type,
		line_nr = token.line_nr,
		file = token.file,
		line_txt = token.line_txt,
		line_pos = token.line_pos or 0
	}
	return node
end

local function ensure(stream, t_type)
	local t = stream:peek()
	error.assert(t.type == t_type, t, "Expected token "..t_type)
end

local function maybe_eat(stream, t_type)
	local t = stream:peek()
	--check_keyword(t)
	if t.type == t_type then stream:next(); return true end
	return false
end

local function eat(stream, t_type)
	local t = stream:peek()
	error.assert(t.type == t_type, t, "Unexpected token")
	stream:next()
end

local parse_exp,
	args

local function parse_prefix(tok,ast)
	tok:eat_newline(true)
	local token = tok:peek()
	local prefix
	if token == nil or token.type == "EOF" then return nil end

	error.assert(token.type == "identifier" or
				token.type == "lparen", token, "Expected identifier or expression")

	local last_type = ""
	-- Eat Name or ( exp ) as first prefix
	-- This handles the case of
	if token.type == "identifier" then
		prefix = create_node(tok, token, "var")
		prefix.name = token.content
		eat(tok, "identifier")
		last_type = "var"
	elseif token.type == "lparen" then
		eat(tok, "lparen")
		prefix = create_node(tok, token, "prefixexp")
		prefix.exp = parse_exp(tok, ast)
		eat(tok, "rparen")
		last_type = "prefixexp"
	end

	local parsed = true
	local current_node = prefix
	while parsed do
		local new_exp
		parsed = false
		token = tok:peek()
		if token.type == "lsqbracket" then
			-- exp (var)
			-- ]
			eat(tok,"lsqbracket")
			new_exp = create_node(tok, token, "var_index")
			new_exp.prefixexp = current_node
			new_exp.exp = parse_exp(tok, ast)
			eat(tok,"rsqbracket")
			parsed = true
			last_type = "var_index"
		elseif token.type == "dot" then
			-- Name (var)
			eat(tok, "dot")
			ensure(tok,"identifier")
			token = tok:peek()
			new_exp = create_node(tok, token, "var_member")
			new_exp.prefixexp = current_node
			new_exp.name = token.content
			eat(tok, "identifier")
			parsed = true
			last_type = "var_member"
		elseif token.type == "colon" then
			-- Name (func)
			-- Args
			eat(tok,"colon")
			ensure(tok,"identifier")
			token = tok:peek()
			new_exp = create_node(tok,token,"func_call")
			new_exp.prefixexp = current_node
			new_exp.name = token.content
			eat(tok,"identifier")
			tok:eat_newline(true)
			new_exp.args = args(tok, ast)
			parsed = true
			last_type = "func_call"
			--return new_exp, last_type
		end
		-- optional argument-list, disable errors
		error.disable()
		tok:eat_newline(true)
		--dbg()
		local a = args(tok,ast)

		error.enable()
		if a ~= nil then
			-- Var with arguments (func)
			new_exp = create_node(tok,token,"func_call")
			new_exp.prefixexp = current_node
			new_exp.args = a
			parsed = true
			last_type = "func_call"
		end

		if parsed then
			current_node.next = new_exp
			current_node = new_exp
		end
	end

	return current_node, last_type
end

args = function(tok, ast)
	--  explist, tableconstructor or plain string
	local token = tok:peek()
	error.assert(token.type == "lparen" or token.type == "lbracket" or token.type == "string", token, "Expected argument-list")

	local node
	if token.type == "string" then
		node = create_node(tok,token,"args")
		node.value = token.content
		eat(tok, "string")
		return node
	end

	if token.type == "lparen" then
		-- explist
		eat(tok, "lparen")
		node = create_node(tok,token,"explist")
		local tmpexp
		node.explist = {}
		repeat
			tmpexp = parse_exp(tok,nil)
			if tmpexp ~= nil then
				table.insert(node.explist,tmpexp)
			end
			token = tok:peek()
			if not maybe_eat(tok, "comma") then tmpexp = nil end
		until tmpexp == nil
		eat(tok, "rparen")
		return node
	elseif token.type == "lbracket" then
		error.assert(false, token, "Unimplemented compiler-feature")
	end
end

parse_exp = function (tok, ast)

	tok:eat_newline(true)
	local token = tok:peek()
	if token == nil or token.type == "EOF" then return nil end

	-- Accept numbers, variables and unary operators
	local out = nil
	if token.type == "lparen" or token.type == "identifier" then
		out = parse_prefix(tok,ast)
		tok:eat_newline(true)
		local next = tok:peek()
		if token.type == "identifier" and next.type == "operator" and next.op_type == "unary" then
			local bin = create_node(tok,next)
			eat(tok,"operator")
			tok:eat_newline(true)
			bin.op = next.content
			bin.op_type = next.op_type
			bin.precedence = next.precedence
			bin.left = out
			bin.right = nil
			out = bin
			next = tok:peek()
		end
		tok:eat_newline(true)
		token = next
	elseif token.type == "number" then
		out = create_node(tok, token)
		out.value = tonumber(token.content)
		ast:addConstant(out.value)
		assert(tok:consume("number"))
		tok:eat_newline(true)
		token = tok:peek()

	elseif token.type == "operator" and
		(token.op_type == "either") then
		--dbg()
		assert(tok:consume("operator"))
		out = create_node(tok, token)
		out.op = token.content
		out.op_type = token.op_type
		out.right = parse_exp(tok, ast)
		tok:eat_newline(true)

		-- Move this to the left branch of next operator since
		-- unary has higher predecence than binary
		if out.right ~= nil and out.right.type == "operator" and
			out.right.op_type ~= nil and
			out.right.op_type == "binary" then
			local oldout = out
			out = out.right
			local oldleft = out.left
			out.left = oldout
			oldout.right = oldleft
		end
		token = tok:peek()
	elseif token.type == "operator" and token.op_type == "unary" then
		assert(tok:consume("operator"))
		local next = tok:peek()
		local op = create_node(tok, token)
		op.op = token.content
		op.op_type = token.op_type
		op.precedence = token.precedence
		op.left = nil
		tok:eat_newline(true)
		if next.type ~= "identifier" then err(token,"Expected identifier") end

		out = create_node(tok, next)
		assert(tok:consume("identifier"))
		out.name = next.content
		ast:addVar(out.name)

		op.right = out
		tok:eat_newline(true)
		out = op
		token = tok:peek()
	elseif token.type == "newline" then err(token, "Parser encountered an invalid state! code 93")
	end

	if out == nil then return nil end

	-- Binary node parsing
	if token ~= nil and token.type == "operator" and
		token.op_type ~= "unary" then
			assert(tok:consume("operator"))

			-- Parse right side of operator
			--dbg()
			tok:eat_newline(true)
			local right = parse_exp(tok, ast)
			local oldOut = out
			out = create_node(tok, token)
			out.op_type = "binary"
			out.precedence = token.precedence
			out.op = token.content
			out.left = oldOut
			out.right = right
			--dbg()
			if out.precedence == nil then dbg() end
			-- Compare predecences and switch if needed
			-- (unary has left = nil and right = exp hence the switch)
			if right ~= nil and right.type == "operator" and
				right.op_type == "binary" and
				(right.precedence < out.precedence or
				out.type == "operator" and
				(out.op_type == "unary" or
				out.op_type == "either")) then

				local oldout = out
				out = right
				local oldleft = out.left
				out.left = oldout
				oldout.right = oldleft
				--dbg()
			end
			tok:eat_newline(true)
			token = tok:peek()
	end
	return out
end

local function parse_var(tok,ast)
	tok:eat_newline(true)
	local token = tok:peek()
	error.assert(token.type == "identifier" or token.type == "lparen", token, "Expected variable declaration")

	local pre,last = parse_prefix(tok,ast)
	error.assert(last == "var")

	return pre
	-- local var = create_node(tok,token,"var")
	-- if token.type == "lparen" then
	-- 	eat(tok,"lparen")
	-- 	token = tok:peek()
	-- 	local exp = parse_exp(tok,ast)
	-- 	error.assert(exp ~= nil, token, "Expected expression")
	-- 	ensure(tok, "rparen")
	-- 	eat(tok,"rparen")
	-- 	pre = create_node(tok,token,"prefixexp")
	-- 	pre.exp = exp
	-- 	var.prefix = pre
	-- else
	-- 	var.name = token.content
	-- 	eat(tok, "identifier")
	-- end
	-- return var
end

local function parse_varlist(tok, ast)
	tok:eat_newline(true)
	local token = tok:peek()
	error.assert(token.type == "identifier",token,"Expected identifier")
	--dbg()
	local out = create_node(tok,token,"varlist")
	out.varlist = {}
	repeat
		local pre = parse_prefix(tok,ast)
		error.assert(pre ~= nil, tok:peek(), "Unknown error")
		error.disable() -- second time around is "optional"

		tok:eat_newline(true)
		token = tok:peek()
		if pre.type == "prefixexp" and token.type == "lsqbracket" then
			local tmp = create_node(tok, token, "var")
			tmp.prefixexp = pre
			eat(tok, "lsqbracket")
			tmp.exp = parse_exp(tok,ast)
			tok:eat_newline(true)
			eat(tok, "rsqbracket")
			table.insert(out.varlist, tmp)
		elseif pre.type == "prefixexp" and token.type == "dot" then
			eat(tok, "dot")
			tok:eat_newline(true)
			token = tok:peek()
			ensure(tok, "identifier")
			local tmp = create_node(tok, token, "var")
			tmp.prefixexp = pre
			tmp.name = token.content
			table.insert(out.varlist, tmp)
		else
			--dbg()
			error.enable()
			error.assert(pre.type == "var" or pre.type ~= "func_call",pre,"Expected variable declaration")
			error.disable()
			table.insert(out.varlist, pre)
			print(pre.name)
		end
		--dbg()
		tok:eat_newline(true)
		token = tok:peek()
		if token.type ~= "comma" then break end
		eat(tok, "comma")
		tok:eat_newline(true)
		token = tok:peek()
		ensure(tok, "identifier")
	until token.type ~= "identifier"
	error.enable()
	if #out.varlist == 0 then return nil end
	return out
end

local function parse_explist(tok,ast)
	tok:eat_newline(true)
	local token = tok:peek()
	--error.assert(token.type == "identifier",token,"Expected identifier")

	local out = create_node(tok,token,"explist")
	out.explist = {}
	repeat
		local exp = parse_exp(tok, ast)
		error.assert(exp ~= nil, token, "Internal error")
		error.disable()
		if exp ~= nil then
			table.insert(out.explist, exp)
			tok:eat_newline(true)
			token = tok:peek()
			if not maybe_eat(tok, "comma") then exp = nil end
		end
	until exp == nil
	error.enable()
	return out
end

local function parse_stat(tok, ast)
	-- varlist = explist
	--dbg()
	local token = tok:peek()
	if token.type == "EOF" then return nil end
	local varlist = parse_varlist(tok,ast)
	tok:eat_newline(true)
	--ensure(tok, "operator")
	local token = tok:peek()
	error.assert(token.content == "=",token,"Expected assignment operator")
	--dbg()
	eat(tok, "operator")
	local explist = parse_explist(tok,ast)

	local out = create_node(tok,tok:peek(),"varlist")
	out.varlist = varlist
	out.explist = explist

	return out
end

local function internal_parse(tok)
	local AST = {}
	AST.nodes = {}
	AST.node_count = 0

	-- List of all variables and how many times they are used
	AST.variables = {}
	AST.addVar = function(ast, var)
		ast.variables[var] = (ast.variables[var] or 0) + 1
	end

	AST.constants = {}
	AST.addConstant = function(ast, const)
		ast.constants[const] = (ast.constants[const] or 0) + 1
	end


	local node = parse_stat(tok, AST)

	while node ~= nil do
		print("Found statement: "..tostring(node.type).."-"..
				tostring(node.op_type))
		table.insert(AST.nodes, node)
		node = parse_stat(tok, AST)
	end

	if tok:has_next() then
		print("WARNING! Parser didn't parse the whole file")
		print("Token found "..tok:peek().type.."["..tok:peek().content.."]")
		module.printAST(AST)
	end

	AST.node_count = #AST.nodes
	return AST
end


module.parse = function(tok)
	assert(tok)
	tok:push()
	local a = internal_parse(tok)
	tok:pop()
	return a
end

local function write_space(count)
	for i=0,count-1, 1 do io.write("   ") end
end

local function print_node(node, indent)
	if indent == nil then indent = -1 end
	if node == nil then return end
	if node.type == "identifier" then
		write_space(indent)
		print("ident: \""..tostring(node.name).."\"")
	elseif node.type == "operator" then
		print_node(node.left, indent + 1)
		write_space(indent + 1)
		print("op ("..tostring(node.op_type)..") "..tostring(node.op))
		print_node(node.right, indent + 1)
	elseif node.type == "number" then
		write_space(indent)
		print("num: "..tostring(node.value))
	elseif node.type == "exp" then
		print_node(node.exp, indent)
	elseif node.type == "prefixexp" then
		write_space(indent)
		print("prefixexp")
		print_node(node.exp, indent)
	elseif node.type == "var" then
		write_space(indent)
		print("var: "..node.name)
	elseif node.type == "varlist" then
		write_space(indent)
		--dbg()
		print("varlist("..#node.varlist.varlist.."): ")
		--dbg()
		for i, v in ipairs(node.varlist.varlist) do
			print_node(v,indent+1)
			if i < #node.varlist.varlist-1 then print(",") end
		end
		print("explist("..#node.explist.explist.."):")
		for i,v in ipairs(node.explist.explist) do
			print_node(v,indent+1)
			if i < #node.explist.explist-1 then print(",") end
		end
	elseif node.type == "var_member" then
		write_space(indent)
		if node.prefixexp ~= nil then print_node(node.prefixexp, indent) end
		print("- var_member: "..node.name)
	elseif node.type == "var_index" then
		write_space(indent)
		--dbg()
		if node.prefixexp ~= nil then print_node(node.prefixexp, indent) end
		io.write("- var_index exp: ")
		print_node(node.exp, indent)
	elseif node.type == "func_call" then
		write_space(indent)
		if node.prefixexp ~= nil then print_node(node.prefixexp, indent) end
		io.write("- func call: "..node.name)
		print_node(node.args, indent)
	elseif node.type == "args" then
		write_space(indent)
		print("args "..(node.value or ""))
		if node.explist ~= nil then print_node(node.explist, indent) end
	else
		write_space(indent)
		io.write("[Unknown:"..node.type.."]")
	end
end


module.printAST = function(ast)
	if ast == nil then return end
	print("--AST BEGIN--")
	for k,node in pairs(ast.nodes) do
		print_node(node) print("") --newline
	end
	if #ast.nodes == 0 then print("- empty -") end

	if #ast.variables > 0 then
		print("Variables and their usage counts;")
		for k,v in pairs(ast.variables) do
			print("	"..tostring(k).." (used: "..v.." times)")
		end
	end

	if #ast.constants > 0 then
		print("Constants and their usage counts;")
		for k,v in pairs(ast.constants) do
			print("	"..tostring(k).." (used "..v.." times)")
		end
	end
	print("--AST END--")

end

return module