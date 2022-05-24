require("util")
local dbg = require("debugger")
local module = {}
local enabled = true

module.err = function(node, msg)
    if not enabled then --print("Discarded error; "..msg)
        return
    end
    if node ~= nil then
		print("------------------------")
		print(tostring(node.file or "Unknown")..":"..tostring(node.line_nr or 0).." - Syntax error ")
		print(tostring(node.line_txt or "[Source not avaliable]"))
        local line = ""
        -- move caret to error location in text
        -- We need to add tabs in the correct place
        -- because of formattnig and how tabs can have different sizes..sigh..
        for i=1, node.line_pos, 1 do
            local c = string.sub(node.line_txt, i,i)
            if c == "\t" then line = line .. "\t"
            else line = line .. " " end
        end
        io.write(line)
        print("^")
        print(tostring(msg or ""))
        dbg()
    else
		print("Unknown compiler error! "..tostring(msg or ""))
	end
end

module.enable = function()
    enabled = true
end
module.disable = function()
    enabled = false
end

module.assert = function(v, n, msg)
    if not enabled then --print("Discarded error: "..(msg or ""))
        return
    end
    if v ~= nil and v then return end
    module.err(n, msg)
    os.exit()
end

return module