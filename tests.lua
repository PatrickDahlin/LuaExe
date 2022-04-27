local adaptivestream = require("adaptivetokenstream")
local util = require "util"

--local f = tokenstream.new("mysrc.b")
local f = adaptivestream.new("mysrc.b")

local num_cb = function(n) n.value = tonumber(n.content); return n end
local op_cb = function(n)
	if 	   n.content == "=" then n.op_type = "binary"
								 n.precedence = 0
	elseif n.content == "+=" then n.op_type = "binary"
								 n.precedence = 0
	elseif n.content == "-=" then n.op_type = "binary"
								 n.precedence = 0
	elseif n.content == "+" then n.op_type = "either"
								 n.precedence = 1
	elseif n.content == "-" then n.op_type = "either"
								 n.precedence = 1
	elseif n.content == "*" then n.op_type = "binary"
								 n.precedence = 2
	elseif n.content == "/" then n.op_type = "binary"
								 n.precedence = 2
	elseif n.content == "%" then n.op_type = "binary"
								 n.precedence = 2
	elseif n.content == "++" then n.op_type = "unary"
								 n.precedence = 3
	elseif n.content == "--" then n.op_type = "unary"
								 n.precedence = 3
	end
	n.op = n.content
	return n
end

f:add_token_match("%a%w*_*%w*", "identifier")
f:add_token_match("%d+", "number", num_cb)
f:add_token_match("%+%+", "operator", op_cb)
f:add_token_match("%+", "operator", op_cb)
f:add_token_match("%-%-", "operator", op_cb)
f:add_token_match("%-", "operator", op_cb)
f:add_token_match("%*", "operator", op_cb)
f:add_token_match("%/", "operator", op_cb)
f:add_token_match("%(", "parenthesis")
f:add_token_match("%)", "parenthesis")
f:add_token_match("%=", "operator", op_cb)
f:add_token_match("%+%=", "operator", op_cb)
f:add_token_match("%-%=", "operator", op_cb)
f:add_token_match("% *", "whitespace")

f:push()

local n = f:peek()
while n ~= nil and n.type ~= "EOF" do

	local line = n.content
	line = line:gsub("\n", "\\n")-- replace newline with backslash n to prevent a newline being printed literally
    line = line:gsub("\r", "\\r")
    print("token: "..n.type.." offset: "..tostring(n.line_pos)..
		" content: ["..line.."] type: "..(n.op_type or "n/a"))

    f:consume(n.type)
	if n.type == "newline" then
		print("Parsed from line "..n.line_nr..":\""..n.line_txt.."\"")
	end

	n = f:peek()
end

f:pop()

f:close()
f = nil

local a, b, c, d = match_pattern("  aa\
\
b = 2","% *")--"%a%w*_*%w*")

print("|"..a.."|")
print("|"..(b or "").."|")
print(c)
print(d)
print("-----")

a, b, c, d = match_pattern(a, "%a%w*_*%w*")

print("|"..a.."|")
print("|"..(b or "").."|")
print(c)
print(d)
print("-----")

a, b, c, d = match_pattern(a, "\n")

print("|"..a.."|")
print("|"..(b or ""):gsub("\n","\\n").."|")
print(c)
print(d)
print("-----")
