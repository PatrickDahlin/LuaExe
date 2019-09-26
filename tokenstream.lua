local create_node = require("nodes")
local module = {}

-- Matches string against pattern with return values:
-- string - the string with pattern removed if found
-- string - value of the matched string
-- int - offset to move cursor
-- int - number of whitespaces before pattern
local function match_pattern(str, pat)
	local a, b = string.match(pat, "^()%s*()"..pat.."()")
	if a == nil then return str, nil, 0, 0 end
	return string.sub(str, b), string.sub(str, a, b-1), b, a
end

local next, 	-- Moves stream one token forward and return token
	peek, 		-- Parses token but doesn't move stream forward
	consume, 	-- Param; string - token type to "eat"
	push, 		-- Push stream state
	pop, 		-- Pop stream state, returning it to a previous state
	has_next, 	-- Returns wether stream has content left to give
	read_next, 	-- Reads in next line from source
	close 		-- Closes the stream

-- Main creation method
module.new = function(filename)
	tokenstream = {
		line_txt = "",
		line_pos = 1,
		line_unparsed = "",
		line_nr = 0,
		filehandle = io.open(filename, "r"),
		file_pos = 0,
		states = {} 
	}

	if tokenstream.filehandle == nil then
		error("Couldn't read file "..filename)
	end

	tokenstream.lines = tokenstream.filehandle:lines()
	tokenstream.next = next
	tokenstream.peek = peek
	tokenstream.consume = consume
	tokenstream.push = push
	tokenstream.pop = pop
	tokenstream.has_next = has_next
	tokenstream.read_next = read_next
	tokenstream.close = close
	tokenstream.token = {type="BOF"}

	-- Make members private and only allow function calls
	
	tokenstream_mt = {
		__newindex = function(t, k, v)
			error("Tried to modify read-only table ["..tostring(k).."] = "..tostring(v))
		end,
		__index = function(t, k)
			local a = rawget(t, k)
			if type(a) ~= "function" then error("Cannot access private members") end
		end,
		__metatable = nil
	}
	setmetatable(tokenstream, tokenstream_mt)
	return tokenstream
end

has_next = function(stream)
	if stream.filehandle == nil or 
		stream.lines == nil then return false end
	local pos = stream.filehandle:seek("cur")
	local has = stream.lines()
	if has == "" or has == nil then return false end
	stream.filehandle:seek("set", pos)
	stream.lines = stream.filehandle:lines()
	return true
end

close = function(stream)
	if stream.filehandle ~= nil then stream.filehandle:close(); stream.filehandle = nil end
end

next = function(stream, peek)
	if stream == nil then return nil end
	if stream.filehandle == nil then return nil end
	
	local node
	local line, match, len, offset

	local function update_stream()
		node.content = match
		node.line_pos = stream.line_pos + offset
		node.line_nr = stream.line_nr
		node.line_txt = stream.line_txt
		if peek == nil or not peek then
			stream.line_pos = stream.line_pos + len
			stream.file_pos = stream.file_pos + len
			stream.line_unparsed = line
			stream.token = node
		end
	end

	-- Read next line if no unparsed txt, return EOF if no more to read
	if stream.line_unparsed == "" then 
		if peek ~= nil and peek then stream:push() end
		if stream:read_next() then
			node = create_node.newline()
			match = "\n"
			len = 1
			offset = 0
			line = stream.line_unparsed
			update_stream()
			if peek ~= nil and peek then 
				stream:pop()
			end
			return node
		else
			node = create_node.eof()
			match = ""
			len = 1
			offset = 0
			line = stream.line_unparsed
			update_stream()
			return node
		end
	end



	

	-- Identifer
	local line, match, len, offset = match_pattern(stream.line_unparsed, "%a%w*_*%w*")
	if node == nil and match ~= nil then
		node = create_node.identifier()
		update_stream()
		return node
	end
	-- Operators
	line, match, len, offset = match_pattern(stream.line_unparsed, "%=")
	if node == nil and match ~= nil then
		node = create_node.operator("binary", match)
		update_stream()
		return node
	end
	line, match, len, offset = match_pattern(stream.line_unparsed, "%+")
	if node == nil and match ~= nil then
		node = create_node.operator("either", match)
		update_stream()
		return node
	end
	line, match, len, offset = match_pattern(stream.line_unparsed, "%-")
	if node == nil and match ~= nil then
		node = create_node.operator("either", match)
		update_stream()
		return node
	end
	line, match, len, offset = match_pattern(stream.line_unparsed, "%*")
	if node == nil and match ~= nil then
		node = create_node.operator("binary", match)
		update_stream()
		return node
	end
	line, match, len, offset = match_pattern(stream.line_unparsed, "%/")
	if node == nil and match ~= nil then
		node = create_node.operator("binary", match)
		update_stream()
		return node
	end

	-- Numbers
	line, match, len, offset = match_pattern(stream.line_unparsed, "%d+%.?%d*")
	if node == nil and match ~= nil then
		node = create_node.number()
		update_stream()
		return node
	end

	-- Parenthesis
	line, match, len, offset = match_pattern(stream.line_unparsed, "%(")
	if node == nil and match ~= nil then
		node = create_node.parenthesis()
		update_stream()
		return node
	end
	line, match, len, offset = match_pattern(stream.line_unparsed, "%)")
	if node == nil and match ~= nil then
		node = create_node.parenthesis()
		update_stream()
		return node
	end
	
	return nil
end

read_next = function(stream)
	if stream == nil or stream.lines == nil then return false end
	if stream.filehandle == nil then return false end
	local line = stream.lines()
	if line == nil then
		stream.line_txt = ""
		stream.line_pos = 1
		return false
	else
		stream.line_txt = line
		stream.line_nr = (stream.line_nr or 0) + 1
		stream.line_pos = 1
		return true
	end
end

peek = function(stream)
	if stream == nil then return nil end
	return stream:next(true)
end


consume = function(stream, tokenType)
	if stream ~= nil and stream.token.type == tokenType then
		return stream:next()
	else
		return nil
	end
end


push = function(stream)
	local copy = {}
	for k, v in pairs(stream) do
		if type(v) ~= "function" then
			copy[k] = v
		end
	end
	table.insert(stream.states, copy)
end


pop = function()
	if #stream.states == 0 then error("Tried popping state when no state was found!") end
	local state = stream.states[#stream.states]
	for k,v in pairs(state) do
		stream[k] = v
	end
	table.remove(stream.states)
	if stream.filehandle ~= nil then
		stream.filehandle:seek("set", stream.file_pos)
		stream.lines = stream.filehandle:lines()
	end
end


return module