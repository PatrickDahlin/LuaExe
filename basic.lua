local parser = require("parser")
local syntax = require("syntax")
local emitter = require("asm_emitter")
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


local nasm_cmd = "nasm -f win64 build.asm -o build.o"
local gcc_cmd = "gcc build.o -o build.exe"

-- Delete old build
os.execute("@del build.exe")



print("Emitting asm")
emitter.compile(ast)

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
print("Done")
