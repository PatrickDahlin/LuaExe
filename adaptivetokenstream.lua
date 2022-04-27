--[[

	Adaptive Token Stream is made as a file-reader that converts input to tokens
	in a streamed fashion. This tokenization process can be customized using
	custom regex-like patterns and therefore is expandable to many different
	user-defined tokens

]]
local util = require("util")
local dbg = require("debugger")
local module = {}


--	==========================================
--
--	INTERNAL: creates a new node of type
--
--	==========================================
local function _make_node(stream, type, content)
	local n = {}
	n.content = content
	n.type = type
	n.line_pos = stream.line_pos
	n.line_nr = stream.line_nr
	n.line_txt = stream.line_txt:gsub("\r\n",""):gsub("\n","")
	n.file = stream.file
	return n
end

--	==========================================
--
--	INTERNAL: Tries to match pattern and moves stream forward if successful
--
--	==========================================
local function _stream_try_pattern(stream, pat, typ, move_stream)
	line, match, len, offset = match_pattern(stream.line_unparsed, pat)
	if match == nil then return nil end

	node = _make_node(stream, typ, match)
	node.line_pos = (node.line_pos + offset) or 0

	if move_stream ~= nil and move_stream then
		stream.line_pos = stream.line_pos + len
		stream.file_pos = stream.file_pos + len
		stream.line_unparsed = line
	end
	return node
end

-- Functions in stream
local next,
		peek,
		consume,
		push,
		pop,
		has_next,
		eat_newline,
		eat_whitespace,
		close,
		add_token_match,
		next_unparsed_line

--	==========================================
--
--	Create a new tokenstream from file
--
--	==========================================
module.new = function(filename)
	-- stream object returned to the user
	-- it contains state information of the stream
	-- as well as functions to advance the stream
	local stream = {
		line_txt = "",		-- Current line as a whole
		line_pos = 1,		-- Where in the line are we currently, offset from beginning
		line_unparsed = "", -- Current line but contains only unparsed data
		line_nr = 1,		-- Line number in the file
		file = filename,	-- Location of the file
		file_pos = 0,		-- Offset into the file where we currently are at
		file_txt = "",		--
		file_unparsed = "", --
		states = {},		-- Internal state objects used for push/pop
		token_matches = {}
	}

	stream.filehandle = io.open(filename, "r")
	if stream.filehandle == nil then
		error("Couldn't read file "..filename)
	end
	stream.file_txt = stream.filehandle:read("*a")
	stream.file_unparsed = stream.file_txt
	stream.filehandle:close()
	stream.filehandle = nil

	stream.next = next
	stream.peek = peek
	stream.consume = consume
	stream.push = push
	stream.pop = pop
	stream.has_next = has_next
	stream.eat_newline = eat_newline
	stream.eat_whitespace = eat_whitespace
	stream.close = close
	stream.next_unparsed_line = next_unparsed_line

	stream.add_token_match = add_token_match

	return readonly(stream)
end

--	==========================================
--
--	Adds a pattern for a token
--
--	==========================================
add_token_match = function(stream, pattern, token_type, matched_func)
	table.insert(stream.token_matches, {pattern = pattern, 
										type = token_type,
										matched_callback = matched_func})
end


--	==========================================
--
--	Returns wether there are tokens left to be parsed
--
--	==========================================
has_next = function(stream)
	return stream:peek().type ~= "EOF"
end

next_unparsed_line = function(stream)
	local s,m,e = stream.file_unparsed:match("()[^\r\n]*()[\r\n]?()")
	local line = stream.file_unparsed:sub(s,m)
	if stream.file_unparsed == "" then line = nil end
	return line, e
end

--	==========================================
--
--	INTERNAL: Moves stream forward by 'n' and sets line_unparsed
--
--	==========================================
local function _move_stream(stream, n, unparsed)
	stream.line_pos = stream.line_pos + n
	stream.file_pos = stream.file_pos + n
	stream.line_unparsed = unparsed
end


--	==========================================
--
--	INTERNAL: Shared parse method that doesn't move stream forward
--
--	==========================================
local function _internal_parse(stream)
	assert(stream)

	local node

	if trim(stream.line_unparsed) == "" then
		local line, end_cursor = stream:next_unparsed_line()

		if line == nil then
			-- eof
			node = _make_node(stream, "EOF", "")
		else
			-- newline
			if stream.file_pos > 0 then
				node = _make_node(stream, "newline", "\n")
				stream.line_nr = stream.line_nr + 1
			end
			_move_stream(stream, 1, line)
			stream.line_txt = line or "nil"
			stream.line_pos = 0
			stream.file_unparsed = stream.file_unparsed:sub(end_cursor)
			stream.file_pos = stream.file_pos + end_cursor
		end
	end

	if node == nil then
		for k,v in pairs(stream.token_matches) do
			local a = _stream_try_pattern(stream, v.pattern, v.type, true)

			if a ~= nil then
				if v.matched_callback ~= nil then a = v.matched_callback(a) end
				return a
			end
		end
	end

	if node == nil then
		print("ERROR; No matching pattern found for '"..stream.line_unparsed.."'")
		dbg()
	end

	return node
end


--	==========================================
--
--	Parse next token and move stream forward
--
--	==========================================
next = function(stream)
	local n = _internal_parse(stream)
	return n
end

--	==========================================
--
--	Parse next token but leave stream where it's at
--
--	==========================================
peek = function(stream)
	stream:push()
	local n = _internal_parse(stream)
	stream:pop()
	return n
end

--	==========================================
--
--	Returns true when given token matches current and moves stream forward, false otherwise
--
--	==========================================
consume = function(stream, token)
	if stream:peek().type == token then
		stream:next()
		return true
	end
	return false
end

--	==========================================
--
--	Eats tokens until non-newline token is found
--
--	==========================================
eat_newline = function(stream, include_whitespace)
	while stream:peek().type == "newline" or (include_whitespace and stream:peek().type == "whitespace" or not include_whitespace or include_whitespace == nil) do
		stream:next()
	end
end

eat_whitespace = function(stream)
	local tok = stream:peek().type
	while tok == "whitespace" or tok == "newline" do
		stream:next()
		tok = stream:peek().type
	end
end

--	==========================================
--
--	Push the stream state, used to revert stream back using pop
--
--	==========================================
push = function(stream)
	local copy = {}
	for k,v in pairs(stream) do
		if type(v) ~= "function" then
			copy[k] = v
		end
	end
	table.insert(stream.states, copy)
end

--	==========================================
--
--	Pop the state stack and revert stream to that state
--
--	==========================================
pop = function(stream)
	assert(#stream.states > 0)
	local state = stream.states[#stream.states]
	for k,v in pairs(state) do
		stream[k] = v
	end
	table.remove(stream.states)
end

--	==========================================
--
--	Closes filehandle for this stream, stream cannot be used after this
--
--	==========================================
close = function(stream)
	--if stream.filehandle ~= nil then stream.filehandle:close(); stream.filehandle = nil end
end

return module
