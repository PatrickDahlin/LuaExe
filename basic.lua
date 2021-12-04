local parser = require("parser")
local syntax = require("syntax")
local emitter = require("nasm_emitter")
--local dbg = require("debugger")
local IR = require("IR_translator")

--local tokenstream = require("tokenstream")
local adaptivestream = require("adaptivetokenstream")

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

f:push()

local n = f:peek()
while n ~= nil and n.type ~= "EOF" do
	local line = n.content
	line = line:gsub("\n", "\\n") 
	print("token: "..n.type.." offset: "..tostring(n.line_pos)..
		" content: ["..line.."] type: "..(n.op_type or "n/a"))
	f:consume(n.type)
	if n.type == "newline" then 
		io.write("Parsed from line "..n.line_nr..":\"")
		io.write(n.line_txt)
		print("\"")
	end	
	n = f:peek()
end

f:pop()

f:close()
f = nil

local start = os.clock()
--f = tokenstream.new("mysrc.b")
f = adaptivestream.new("mysrc.b")

f:add_token_match("%a%w*_*%w*", "identifier")
f:add_token_match("%d+", "number", num_cb)
f:add_token_match("%+%+", "operator", op_cb)
f:add_token_match("%+", "operator", op_cb)
f:add_token_match("%-%-", "operator", op_cb)
f:add_token_match("%-", "operator", op_cb)
f:add_token_match("%*", "operator", op_cb)
f:add_token_match("%/", "operator", op_cb)
f:add_token_match("%(", "lparen")
f:add_token_match("%)", "rparen")
f:add_token_match("%[", "lsqbracket")
f:add_token_match("%]", "rsqbracket")
f:add_token_match("%=", "operator", op_cb)
f:add_token_match("%+%=", "operator", op_cb)
f:add_token_match("%-%=", "operator", op_cb)
f:add_token_match("%;", "semicolon")
f:add_token_match("%:", "colon")
f:add_token_match("%.%.%.", "tdot")
f:add_token_match("%.%.", "ddot")
f:add_token_match("%.", "dot")

local ast = parser.parse(f)


local res = syntax.verify(ast)

delta = os.clock() - start
print("Compile time "..(delta*1000).." ms")

io.write("Syntax: ")
if res then print("OK") else print("ERROR") end

print("")
parser.printAST(ast)


local nasm_cmd = "nasm -f win64 build.asm -o build.o -Wall"
local gcc_cmd = "gcc build.o -o build.exe -Wall"

-- Delete old build
os.execute("@del build.exe")

local ir = IR.translate(ast)

for k,v in pairs(ir.code) do
	print(v.type.." "..tostring(v.reg1 or v.size).. " "..tostring(v.reg2 or "").." "..tostring(v.tag or ""))
end

print("Emitting asm")
emitter.emit(ir, "build")

--emitter.compile(ast)

print("Emitted build.asm")

local handle = io.popen(nasm_cmd)
local result = handle:read("*a")
handle:close()

handle = io.popen(gcc_cmd)
result = handle:read("*a")
handle:close()

print("Running application")

handle = io.popen("build.exe")
result = handle:read("*a")
handle:close()

print(tostring(result))
--]]
print("Done")


--[[

chunk, stat, block, laststat, varlist, explist

optional means only *one* instance may exist while
repeat means 0 or more may exist.

chunk.description = {
[1] = {
	{_stat, optional = false, repeat = true},
	{_laststat, optional = true, repeat = false}
}
}

_stat.desc = {
[1] = {
	{stat, repeat = true},
	{";", optional = true}
}
}

_laststat.desc = {
[1] = {
	{laststat, optional = true},
	{";", optional = true}
}
}

laststat.desc = {
[1] = {
	{"return"},
	{explist, optional = true},
},
[2] = {
	{"break"}
}
}


]]