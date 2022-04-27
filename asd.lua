
local file = io.open("mysrc.b", "r")
local all_file = file:read("*a")
file:close()

local pos = 0
local line_nr = 1
local file_len = #all_file

while pos <= file_len do
    local s,m,e = all_file:match("()[^\r\n]*()[\r\n]?()")
    if m == nil then break end
    local line = all_file:sub(s,m)
    --print("start:"..s.." middle:"..m.." end:"..e)
    print("line:\""..line.."\"")
    if e == nil then break end
    pos = pos + e
    all_file = all_file:sub(e)
end




