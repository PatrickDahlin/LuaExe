--[[

	Adaptive Token Stream is made as a file-reader that converts input to tokens
	in a streamed fashion. This tokenization process can be customized using
	custom regex-like patterns and therefore is expandable to many different
	user-defined tokens

]]
local util = require("util")
local module = {}

local try_pattern(stream, pat, typ, move_stream)
	line, match, len, offset = match_pattern(stream.line_unparsed, pat)
	if match == nil then return nil end
	node = {
		type = typ,
		content = match,
		line_pos = stream.line_pos + offset or 0,
		line_nr = stream.line_nr,
		line_txt = stream.line_txt,
		file = stream.file
	}
	if move_stream ~= nil and move_stream then
		stream.line_pos = stream.line_pos + len
		stream.file_pos = stream.file_pos + len
		stream.line_unparsed = line
	end
	return node	
end

local next, peek, consume, push, pop, has_next, eat_newline, close, add_token_match

module.new = function(filename)
	-- stream object returned to the user
	-- it contains state information of the stream
	-- as well as functions to advance the stream
	local stream = {
		line_txt = "",		-- Current line as a whole
		line_pos = 1,		-- Where in the line are we currently, offset from beginning
		line_unparsed = "", -- Current line but contains only unparsed data
		line_nr = 0,		-- Line number in the file
		file = filename,	-- Location of the file
		file_pos = 0,		-- Offset into the file where we currently are at
		states = {},		-- Internal state objects used for push/pop
		token_matches = {}
	}

	stream.filehandle = io.open(filename, "r")
	if stream.filehandle == nil then
		error("Couldn't read file "..filename)
	end

	stream.lines = stream.filehandle:lines()
	stream.next = next
	stream.peek = peek
	stream.consume = consume
	stream.push = push
	stream.pop = pop
	stream.has_next = has_next
	stream.eat_newline = eat_newline
	stream.close = close

	stream.add_token_match = add_token_match

	return readonly(stream)
end

add_token_match = function(stream, pattern, token_type)
	table.insert(stream.token_matches, {pattern = pattern, type = token_type})
end

has_next = function(stream)
	return stream:peek().type ~= "EOF"
end

next = function(stream)
end

peek = function(stream)
end

consume = function(stream, token)
	if stream:peek().type == token then
		stream:next()
		return true
	end
	return false
end

eat_newline = function(stream)
	while stream:peek().type == "newline" do
		stream:next()
	end
end

push = function(stream)
end

pop = function(stream)
end

close = function(stream)
	if stream.filehandle ~= nil then stream.filehandle:close(); stream.filehandle = nil end
end

return module
