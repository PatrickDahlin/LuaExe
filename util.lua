local match = string.match
function trim(s)
   return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end