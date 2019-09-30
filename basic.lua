local parser = require("parser")
local syntax = require("syntax")
local dbg = require("debugger")

local tokenstream = require("tokenstream")

local f = tokenstream.new("mysrc.b")


f:push()

local n = f:peek()
while n ~= nil and n.type ~= "EOF" do
    print("token: "..n.type.." offset: "..tostring(n.line_pos).." content: ["..n.content.."]")
    f:consume(n.type)
    n = f:peek()
end

f:pop()

local ast = parser.parse(f)

parser.printAST(ast)

local res = syntax.verify(ast)
io.write("Syntax: ")
if res then print("OK") else print("ERROR") end


print("Done")

