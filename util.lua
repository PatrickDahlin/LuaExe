local match = string.match
function trim(s)
   return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end

function readonly(t)
   local mt = {
		__newindex = function(t, k, v)
			error("Tried to modify read-only table ["..tostring(k).."] = "..tostring(v))
		end,
		__index = function(t, k)
			local a = rawget(t, k)
			if type(a) ~= "function"  then error("Cannot access private members") end
		end,
		__metatable = nil
	}
	setmetatable(t, mt)
   return t
end

-- Matches string against pattern with return values:
-- string - the string with pattern removed if found
-- string - value of the matched string
-- int - offset to move cursor
-- int - number of whitespaces before pattern
function match_pattern(str, pat)
	--dbg()
	local a, b = string.match(str, "^%s*()"..pat.."()")
	if a == nil then return str, nil, 0, 0 end
	return string.sub(str, b), string.sub(str, a, b-1), b-1, a-1
end

-- Counts tabs in string until limit count is hit
function count_tabs(s, lim)
   local count = 0
   if lim == nil or lim > #s then lim = #s end
   for i = 1, lim do
      local c = string.sub(s,i,i)
      if string.byte(c) == 9 then
         count = count + 1
      end
   end
   return count
end