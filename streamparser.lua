local module = {}
local dbg = require("debugger")
local error = require("error")

-- syntax.base contains the root-node
local syntax = require("lua_syntax_tree")

local keywords = {
	"local", "function",
	"return", "break",
	"nil", "true",
	"false", "if",
	"else", "end",
	"elseif", "do",
	"for", "repeat",
	"and", "or", 
	"not", "in",
	"until", "while"
}

local function check_keyword(node)
	if node == nil then return end
	if node.type ~= "identifier" then return end
	for k in keywords do
		if node.content == k then
			node.type = "keyword"; return
		end
	end
end

--[[

]]

local func_call, 
		varlist, 
		var,
		prefixexp,
		args,
		do_block,
		while_block,
		repeat_block,
		if_block,
		for_block,
		func_decl,
		local_func_decl,
		local_namelist,
		exp,
		local_decl

local function eat(stream, t_type)
	local t = check_keyword(stream.peek())
	error.assert(t.type == t_type, t, "Unexpected token")
end

local function maybe_eat(stream, t_type)
	local t = stream.peek()
	check_keyword(t)
	if t.type == t_type then stream.next(); return true end
	return false
end


local function make_var(stream)
	if stream.peek().type == "identifier" then
		return {type="var", name=stream.next().content}
	else return nil end
end

local function prefixexp(stream)
	local peek = check_keyword(stream.peek())
	-- Name or '('
	if not (peek.type == "identifier" or peek.type == "lparen") then
		return nil
	end

	local n, is_var
	if peek.type == "identifier" then
		n = {type="prefixexp",var=make_var(stream)}
		is_var = true
	else -- can only be lparen aka expression within parens
		eat(stream, "lparen")
		n = {type="prefixexp",exp=exp(stream)}
		eat(stream, "rparen")
		is_var = false
	end

	if maybe_eat(stream, "lsqbracket") then
		n = {type="prefixexp", prefixexp=n, exp=exp(stream)}
		eat(stream, "rsqbracket")
	
	elseif maybe_eat(stream, "dot") then
		error.assert(stream.peek().type == "identifier", stream.peek(), 
						"Expected identifier")
		n = {type="prefixexp", prefixexp=n, var=stream.peek().content}
		eat(stream, "identifier")
	
	end
end


-- Parse variable, has to begin with either identifier or a leftparen
--  since we can have expression following member access
local function var(stream)
	local peek = check_keyword(stream.peek())
	if not (peek.type == "identifier" or peek.type == "lparen") then
		return nil
	end

	local n, force_next
	if peek.type = "lparen" then
		
		n = {type="var",prefixexp=prefixexp(stream)}

		error.assert(n.prefixexp ~= nil, stream.peek(), "Found left parenthesis, expected end paren following expression")
		-- A prefix alone can't be a variable
		force_next = true
	elseif peek.type == "identifier" then
		n = {type="var",name=peek.content}
		eat(stream, "identifier")
		force_next = false -- This can be a terminal
	end
	
	-- prefix consumed, now expect either indexing exp or dot Name
	if maybe_eat(stream, "lsqbracket") then
		-- If we found an identifier, we treat it as a prefix
		if not force_next then n = {type="var", prefix=n} end

		n.exp = exp(stream)
		eat(stream, "rsqbracket")

	elseif maybe_eat(stream, "dot") then
		-- Treat ident as prefixexp
		if not force_next then n = {type="var", prefix=n} end

		peek = check_keyword(stream.peek())
		eat(stream, "identifier")
		n.name = peek.content

	elseif force_next then
		error.err(peek, "Expected identifier or prefix expression")
	end
	
	return n
end

local function for_block(AST, stream, node)
	-- "for" keyword has been found, invalid parse gives error
	-- For keyword can have 2 different layouts,
	-- basic indexed iteration, or simple foreach iterator
	-- both end up in this function, so we need to distinguish
	-- which one is being parsed

end

local function local_decl(AST, stream, node)
	-- Current node is a "local" keyword, invalid parse gives error
	-- We can only have a function declaration
	-- or a namelist, anything else is not permitted
	-- Do note that function decl has different rules than a simple
	-- global function declaration

end

local function varlist_or_call(AST,stream,node)
	-- Parse either a variable list definition
	--  or a function call
	-- No specific node found, no error if nothing can be parsed

end

-- Lookup table for different keywords
--  used for simpler decision making on which
--  method to call based on content
local stat_lookup = {
	["do"] = do_block,
	["while"] = while_block,
	["repeat"] = repeat_block,
	["if"] = if_block,
	["for"] = for_block,
	["function"] = func_decl,
	["local"] = local_decl
}

local function parse_stat(stream)
	local node = stream.next()
	check_keyword(node)

	if node.type == "keyword" then
		error.assert(stat_lookup[node.content] ~= nil, node, "Unexpected keyword")
		return stat_lookup[node.content](stream,node)
	else
		-- Fallback, varlist or func call is only statements left possible
		local n = varlist_or_call(stream,node)
		error.assert(n ~= nil, node, "Unable to parse statement")
		return n
	end
end

local function parse_block(stream)
	local block = {}
	block.statements = {}
	local stat = nil

	while (stat = parse_stat(stream)) ~= nil do
		table.insert(block.statements, stat)
		maybe_eat(stream, "semicolon")
	end

	-- Laststat
	local tmp = stream.peek()
	check_keyword(tmp)
	if tmp.type == "keyword" then
		if tmp.content == "return" then
			block.laststat = {"type"="return", 
								explist = parse_explist(stream)}
		elseif tmp.content == "break" then
			block.laststat = {"type" = "break"}
		end
	end

	maybe_eat(stream, "semicolon")

	return block
end

local function parse_stream(stream)
	-- loop syntax.base and try to match each element
	local AST = {}

	AST.block = parse_block(stream)

	return AST
end

module.parse = function(tok)
	assert(tok)
	tok:push()
	ast = parse_stream(tok)
	tok:pop()
	return ast
end

return module