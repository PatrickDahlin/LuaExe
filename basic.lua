local parser = require("parser")
local syntax = require("syntax")
local dbg = require("debugger")

local tokenstream = require("tokenstream")

local f = tokenstream.new("mysrc.b")


f:push()

local n = f:peek()
while n ~= nil and n.type ~= "EOF" do
	local line = n.content
	line = line:gsub("\n", "\\n") 
	print("token: "..n.type.." offset: "..tostring(n.line_pos)..
		" content: ["..line.."]")
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
f = tokenstream.new("mysrc.b")

local ast = parser.parse(f)


local res = syntax.verify(ast)

delta = os.clock() - start
print("Compile time "..(delta*1000).." ms")

io.write("Syntax: ")
if res then print("OK") else print("ERROR") end

print("")
parser.printAST(ast)


print("Done")

