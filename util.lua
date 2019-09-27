local match = string.match
function trim(s)
   return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end

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