require("util")
local module = {}


-- Match a variable, returns 2 strings, one is a variable and the second
-- is the "leftover" contents
local function match_var(txt)
	if txt == nil then return 0, nil, nil end
	local var_b, var_e = string.match(txt, "^()%a%w*_*%w*()")
	if var_b == nil then return 0, nil, txt end
	return var_e, string.sub(txt, var_b, var_e-1), (string.sub(txt, var_e))
end

-- Matches against any operator (unary/binary)
local function match_op(txt)
	if txt == nil then return 0, nil, nil end
--	+=
	local op_b, op_e = string.match(txt, "^()%+%=()")
	if op_b ~= nil and op_e ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 0
	end
--	-=
	op_b, op_e = string.match(txt, "^%s*()%-%=()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 0
	end
--	++
	op_b, op_e = string.match(txt, "^%s*()%+%+()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "unary", 3
	end
--	--
	op_b, op_e = string.match(txt, "^%s*()%-%-()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "unary", 3
	end
--	=
	op_b, op_e = string.match(txt, "^%s*()%=()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 0
	end
--	+
	op_b, op_e = string.match(txt, "^%s*()%+()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 1
	end
--	-
	op_b, op_e = string.match(txt, "^%s*()%-()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "either", 1
	end
--	*
	op_b, op_e = string.match(txt, "^%s*()%*()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 2
	end
--	/
	op_b, op_e = string.match(txt, "^%s*()%/()")
	if op_b ~= nil then
		return op_e, string.sub(txt, op_b, op_e-1), (string.sub(txt, op_e)), "binary", 2
	end

	return 0, nil, txt
end

-- Matches against any number (int and float)
local function match_num(txt)
	if txt == nil then return 0, nil, nil end
	local num_b, num_e = string.match(txt, "^()%d+%.?%d*()")
	if num_b == nil then return 0, nil, txt end
--	print("NUM,"..string.sub(txt, num_b, num_e-1))
	return num_e, string.sub(txt, num_b, num_e-1), (string.sub(txt, num_e))
end

-- Matches input against parenthesis, right and left paren
local function match_paren(txt)
	if txt == nil then return 0, nil, nil end
	local par_b, par_e = string.match(txt, "^()%(()")
	if par_b == nil then
		par_b, par_e = string.match(txt, "^()%)()")
		if par_b == nil then
			return 0, nil, txt 
		end
	end
	return par_e, (string.sub(txt, par_b, par_e-1)), (string.sub(txt, par_e))
end

local function calcPrefixSpaces(txt)
	--print("Input to calc:"..txt.."]")
	local i = 0
	local a = string.sub(txt, i + 1, i + 1)
	---print("["..tostring(string.byte(a) or -1).."]")
	while a ~= nil and (string.byte(a) == 32 or string.byte(a) == 9) do
		i = i + 1
		if string.byte(a) == 9 then i = i + 3; end
		a = string.sub(txt, i + 1, i + 1)
		--print("["..tostring(string.byte(a) or -1).."]")
	end
	--print("output from calc:"..i)
	return i
end

-- Parse function takes in tokenizer table and parses a token which is returned
-- This token is one of these;
-- variable
-- operator (unary/binary)
-- number
-- parenthesis
-- The optional write param lets the func modify the tokenizer table
--  or uses it as read-only
local function parse(tok, write)

	local line_cache = nil
	local outOffset = 0

	local text = tok.line_txt
	local len = tok.line_len
	local line = tok.line or 0
	local token = nil
	local next_newline = tok._next_is_newline or false
	local end_of_file = tok.end_of_file or false
	local file_seek = tok.filehandle:seek("cur")

	-- Increment line counter after newline token
	if next_newline then 
		line = line + 1
		next_newline = false
		tok.cursor = 1
	end
	-- Resetting line and txt content when at beginning of file
	if tok.filehandle:seek("cur") == 0 then
		text = tok.handle() or ""
		line_cache = text
		len = string.len(text)
		line = 1
		tok.line = 1
		tok.cursor = 1
	end

	-- When current line has been consumed, return a newline / EOF
	--	depending on if the file still has content
	if text == "" or end_of_file then
		-- Read in next line
		text = tok.handle() or ""
		line_cache = text
		len = string.len(text)
		if text == "" then
			token = {type="EOF", content="EOF"}
			end_of_file = true
			text = ""
		else
			next_newline = true
			token = {type = "newline", content=""}
		end
	end
	
	-- Begin parsing of valid expressions

	local offset, var, txt = match_var(text)
	if token == nil and var ~= nil then
		token = {type = "identifier", content = var}
		text = txt
		outOffset = offset
	end
	offset, op, txt, op_type, precedence = match_op(text)
	if token == nil and op ~= nil then
		token = {type = "operator", content = op, op_type = op_type, precedence = precedence }
		text = txt
		outOffset = offset
	end

	offset, num, txt = match_num(text)
	if token == nil and num ~= nil then
		token = {type = "number", content = num}
		text = txt
		outOffset = offset
	end

	offset, paren, txt = match_paren(text)
	if token == nil and paren ~= nil then
		token = {type = "parenthesis", content = paren}
		text = txt
		outOffset = offset
	end

	-- End parsing

	-- Set extra data in each token such as file and line nr
	if token ~= nil then 
	--print("Token offset of "..tok.cursor)
		token.cursor = tok.cursor
		token.line = line
		token.file = tok.file
	end

	-- Change state of tokenizer if allowed to
	if write then
		tok.cursor = tok.cursor + outOffset -1 + calcPrefixSpaces(text)
		tok.line_txt = trim(text)
		tok.token = token or {}
		tok._next_is_newline = next_newline
		tok.line_len = len
		tok.end_of_file = end_of_file
		tok.line = line
		if line_cache ~= nil then tok.line_cache = line_cache end

	else
		-- Return file to earlier state if we don't want to write to tokenizer
		-- TODO Optimize, this means reading same line more than once
		tok.filehandle:seek("set", file_seek)
	end

	return token	
end

local function tok_next(tok)
	local token = parse(tok, true)
	return token
end

local function tok_consume(tok, type)
	local token = parse(tok, false)
	if token ~= nil and token.type == type then 
		parse(tok, true)
		return true
	else
		return false
	end
end

local function tok_peek(tok)
	local token = parse(tok, false)
	return token
end

local function tok_pushmark(tok)
	table.insert(tok.mark, {txt=tok.line_txt,
							line=tok.line,
							line_ln=tok.line_len,
							token=tok.token,
							loc=tok.filehandle:seek() or 0,
							eof=tok.end_of_file,
							cursor=tok.cursor})
end

local function tok_popmark(tok)
	if #tok.mark <= 0 then return end
	local out = {}
	table.insert(out, tok.mark[#tok.mark])
	table.remove(tok.mark) -- removes last elem
	tok.line = out.line or 0
	tok.line_txt = out.txt or ""
	tok.line_len = out.line_ln or 0
	tok.token = out.token or {}
	tok.end_of_file = out.eof or false
	tok.cursor = out.cursor or 1
	local ln, err = tok.filehandle:seek("set",out.loc)
end


module.new = function(filename)

	local tokenizer = {}

	tokenizer.filehandle = io.open(filename, "r")
	if tokenizer.filehandle ==  nil then
		print("file couldn't be opened")
		return nil
	end

	-- Filehandle used to read from the sourcefile
	tokenizer.handle = tokenizer.filehandle:lines()
	-- Name of the file
	tokenizer.file = filename
	-- Next function used to parse a new token
	tokenizer.next = tok_next
	-- Container for current token
	tokenizer.token = {}
	-- Peek the next token without modifying tokenizer state
	tokenizer.peek = tok_peek
	-- Consume given token type, returns false if next token is not of the given type
	-- Params: string - Token type name
	tokenizer.consume = tok_consume
	-- Current line number
	tokenizer.line = 0
	-- Contents left to be parsed on this line
	tokenizer.line_txt = ""
	-- Total initial length of this line
	tokenizer.line_len = 0
	-- Marker that is set true when no more data can be read from file
	tokenizer.end_of_file = false
	-- Method to push tokenizer state to be later popped off
	tokenizer.push_mark = tok_pushmark
	-- Method to reset back tokenizer state to a previous one found on the stack
	tokenizer.pop_mark = tok_popmark
	-- Internal stack of tokenizer states
	tokenizer.mark = {}

	-- Internal variables

	-- flag for newline
	tokenizer._next_is_newline = false
	-- Stores the whole line even if tokens are parsed and cursor moves
	tokenizer.line_cache = ""
	-- Current char position in the line
	tokenizer.cursor = 0

	
	local mt = {}
	mt.__newindex = function(t, k, v) 
		error("Tried to modify read-only table ([" ..
		tostring(k) ..
		"] = " ..
		tostring(v) ..
		")") 
	end
	mt.__index = function(t, k) 
		--local val = rawget(tokenizer, k)
		print("aaaaa"..type(val))
		if type(val) ~= "function" then
			error("Cannot access private members from outside object")
		end
		--return rawget(tokenizer, k)
		return nil
	end

	mt.__call = function(func, ...)
		print("calling func")
		return nil
	end

	setmetatable(tokenizer, mt)

	return tokenizer
end

return module