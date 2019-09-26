local tokenizer = require("tokenizer")
local parser = require("parser")
local syntax = require("syntax")

local tokenstream = require("tokenstream")

local f = tokenizer.new("mysrc.b")
f:push_mark()
print("Looping all tokens:")
local a = f:next()
while a ~= nil and a.type ~= "EOF" do
    print("token: "..a.type.." offset: "..tostring(a.cursor).." content: "..tostring(a.content))
    a = f:next()
end
print("End loop\n")
f:pop_mark()

local ast = parser.parse(f)

parser.printAST(ast)

--local res = syntax.verify(ast)
--io.write("Syntax: ")
--if res then print("OK") else print("ERROR") end


local stream = tokenstream.new("mysrc.b")
stream:next()

print("Done")

