local module = {}
local dbg = require("debugger")
local error = require("error")

-- syntax.base contains the root-node
local syntax = require("lua_syntax_tree")


-- Return node that gave error, otherwise return nil
local function match_node(stream, AST, n)
	local out = nil
	for k,v in pairs(n) do
		if type(v) == "table" then
			-- match sub-node
			out = match_node(stream, AST, v)
		elseif type(v) == "function" then
			-- validator-func
			if v(n) then out = true end
		elseif type(v) == "string" then
			-- content match
			out = v == n.content
		end
		if out ~= nil and out ~= false then break end
	end
	if out then return n else return nil end
end

local function parse_stream(stream)
	-- loop syntax.base and try to match each element
	local AST = {}
	local res = match_node(stream, AST, syntax.base)
	error.assert(res == nil, res, "Parse error")
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