require("util")
local module = {}


module.err = function(node, msg)
	if node ~= nil then
		print("------------------------")
		print(tostring(node.file or "Unknown")..":"..tostring(node.line_nr or 0).." - Syntax error ")
		print(tostring(node.line_txt or "[Source not avaliable]"))
        local line = ""
        -- move caret to error location in text
        -- We need to add tabs in the correct place
        -- because of formattnig and how tabs can have different sizes..sigh..
        for i=1, node.line_pos-1, 1 do
            local c = string.sub(node.line_txt, i,i)
            if c == "\t" then line = line .. "\t"
            else line = line .. " " end
        end
        io.write(line)
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