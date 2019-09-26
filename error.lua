
local module = {}


module.err = function(node, msg)
	if node ~= nil then
		print("------------------------")
		print(tostring(node.file or "Unknown")..":"..tostring(node.line_nr or 0).." - Syntax error ")
		print(tostring(node.line_txt or "[Source not avaliable]"))
		for i=1, node.line_pos or 0, 1 do io.write("-") end
		print("^")
		print(tostring(msg or ""))
		--print("At symbol: "..tostring(node.type)..","..tostring(node.content or node.op or node.name))
	else
		print("Unknown syntax error! "..tostring(msg or ""))
	end
	--dbg()
end

module.assert = function(v, n, msg)
    if v then return end
    module.err(n, msg)
    os.exit()
end

return module