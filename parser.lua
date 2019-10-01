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


local function parse_exp(tok, ast)

	tok:eat_newline()
	local token = tok:peek()
	if token == nil or token.type == "EOF" then return nil end

	-- Accept numbers, variables and unary operators
	local out = nil
	if token.type == "parenthesis" and token.content == "(" then
		local begin_tok = token.line
		tok:consume("parenthesis")
		out = create_node(tok, token, "exp")
		out.exp = parse_exp(tok, ast)
		local prev_token = token
		tok:eat_newline()
		token = tok:peek()
		assert(token ~= nil, token, "Expected expression")
		assert(token.type == "parenthesis" and token.content == ")", 
				prev_token, "Expected closing parenthesis")
		tok:consume("parenthesis")
		tok:eat_newline()
		token = tok:peek()

	elseif token.type == "identifier" then
		out = create_node(tok, token)
		out.name = token.content
		ast:addVar(out.name)
		tok:consume("identifier")
		tok:eat_newline()
		token = tok:peek()

	elseif token.type == "number" then
		out = create_node(tok, token)
		out.value = tonumber(token.content)
		ast:addConstant(out.value)
		tok:consume("number")
		tok:eat_newline()
		token = tok:peek()

	elseif token.type == "operator" and 
		(token.op_type == "unary" or 
		token.op_type == "either") then
		
		tok:consume("operator")
		out = create_node(tok, token)
		out.op = token.content
		out.op_type = token.op_type
		out.right = parse_exp(tok, ast)
		tok:eat_newline()

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
	elseif token.type == "newline" then error("Parser encountered an invalid state! code 93")
	end

	if out == nil then return nil end

	-- Binary node parsing
	if token ~= nil and token.type == "operator" and 
		token.op_type ~= "unary" then
			tok:consume("operator")
			
			-- Parse right side of operator
			local right = parse_exp(tok, ast)
			local oldOut = out
			out = create_node(tok, token)
			out.op_type = "binary"
			out.precedence = token.precedence
			out.op = token.content
			out.left = oldOut
			out.right = right
			
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
			end
	end
	return out
end

local function parse_stat(tok, ast)
	return parse_exp(tok, ast)
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
	end
end


module.printAST = function(ast)
	if ast == nil then return end

	for k,node in pairs(ast.nodes) do
		print_node(node) print("") --newline
	end

	print("Variables and their usage counts;")
	for k,v in pairs(ast.variables) do
		print("	"..tostring(k).." (used: "..v.." times)")
	end

	print("Constants and their usage counts;")
	for k,v in pairs(ast.constants) do
		print("	"..tostring(k).." (used "..v.." times)")
	end

end

return module