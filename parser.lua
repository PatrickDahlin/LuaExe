--[[
	Parser for tokenizer
]]
local module = {}
local write = io.write
local error = require("error")
local err = error.err
local assert = error.assert

local function myassert(val, tok, msg)
	if val ~= nil and val and tok ~= nil then return end
	error("Error in file "..tostring(tok.file)..":"..tostring(tok.line).."  -  "..tostring(msg))
end

local function create_node(tok, token, node_type)
	local node = {
		type = node_type or token.type,
		line_nr = tok.line,
		file = tok.file,
		line_txt = tok.line_cache,
		line_pos = token.cursor or 0
	}
	return node
end

--[[
local function internal_parse_node(tok, ast)

	local token = tok:next()
	if token == nil or token.type == "EOF" then return nil end

	-- Parsing a statement
	-- First parse left side, then the operand, and lastly the right
	-- side expression
	assert(token.type == "identifier", token, "Expected identifier") -- only support variable assignment statements
	local node = {}
	node.left = token
	-- Expect an operator
	token = tok:next()

	
	myassert(token.type == "operator", tok, "Expected identifier")
	node.operator = token
	-- Unary types don't need an right side expression
	if token.op_type ~= nil and token.op_type == "unary" then
		table.insert(ast.nodes, node)
		return node
	end

	node.right = internal_parse_exp(tok, ast)
	myassert(node.right ~= nil, tok, "Assignment value not defined")

	table.insert(ast.nodes, node)
	return node
end
]]

local function parse_exp(tok)
--	print("TOK: "..tok.line_txt)
	local token = tok:peek()
	if token == nil or token.type == "EOF" then return nil end
	if token.type == "newline" then tok:consume("newline") token = tok:peek() end

--	print("Parsing token "..token.type..","..tostring(token.content))
	-- Accept numbers, variables and unary operators
	local out = nil
	if token.type == "parenthesis" and token.content == "(" then
		local begin_tok = token.line
		tok:consume("parenthesis")
		out = create_node(tok, token, "exp")
		out.exp = parse_exp(tok)
		local prev_token = token
		token = tok:peek()
		assert(token ~= nil, token, "Expected expression")
		assert(token.type == "parenthesis" and token.content == ")", prev_token, "Expected closing parenthesis")
		tok:consume("parenthesis")
		token = tok:peek()

	elseif token.type == "identifier" then
		out = create_node(tok, token)
		out.name = token.content
		tok:consume("identifier")
		token = tok:peek()

	elseif token.type == "number" then
		out = create_node(tok, token)
		out.value = tonumber(token.content)
		tok:consume("number")
		token = tok:peek()
--		print("exp-found number")

	elseif token.type == "operator" and 
		(token.op_type == "unary" or token.op_type == "either") then
		
		tok:consume("operator")
		out = create_node(tok, token)
		out.op = token.content
		out.op_type = token.op_type
		out.right = parse_exp(tok)

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
		else
			out = nil
		end
		token = tok:peek()
	end

	if out == nil then return nil end

	-- Binary node parsing
	if token ~= nil and token.type == "operator" and token.op_type ~= "unary" then
			tok:consume("operator")
			
			-- Parse right side of operator
			local right = parse_exp(tok)
			local oldOut = out
			out = create_node(tok, token)
			out.op_type = "binary"
			out.precedence = token.precedence
			out.op = token.content
			out.left = oldOut
			out.right = right
			
			-- Compare predecences and switch if needed (unary has left = nil and right = exp hence the switch)
			if right ~= nil and right.type == "operator" and right.op_type == "binary" and 
				(right.precedence < out.precedence or
				out.type == "operator" and (out.op_type == "unary" or out.op_type == "either")) then
				local oldout = out
				out = right
				local oldleft = out.left
				out.left = oldout
				oldout.right = oldleft
			end
			--			print("EXP, BINOP-Right: "..tostring(out.right))
	end
	return out
end

local function parse_stat(tok)
	return parse_exp(tok)
end

local function internal_parse(tok)
	local AST = {}
	AST.nodes = {}
	AST.node_count = 0
	print("Begin parsing")
	local node = parse_stat(tok)
	
	while node ~= nil and node.type ~= nil do
		print("Found statement: "..tostring(node.type).."-"..tostring(node.op_type))
		table.insert(AST.nodes, node)
		node = parse_stat(tok)
	end
	print("End of parsing")

	AST.node_count = #AST.nodes
	return AST	
end


module.parse = function(tok)
	assert(tok)
	tok:push_mark()
	local a = internal_parse(tok)
	tok:pop_mark()
	return a
end

local function print_node(node)
	if node == nil then return end
	if node.type == "identifier" then
		write("(ident:"..tostring(node.name)..")")
	elseif node.type == "operator" then
		write("(operator ("..tostring(node.op_type)..") left:")
		print_node(node.left)
		write(", '"..tostring(node.op).."', ")
		write("right:")
		print_node(node.right)
		write(")")
	elseif node.type == "number" then
		write("(number:"..tostring(node.value)..")")
	elseif node.type == "exp" then
		write("(exp: ")
		print_node(node.exp)
		write(")")
	end
end


module.printAST = function(ast)
	if ast == nil then return end

	for k,node in pairs(ast.nodes) do
		print_node(node) print("") --newline
	end

end

return module