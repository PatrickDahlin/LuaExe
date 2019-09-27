local module = {}

module.eof = function() return {type="EOF"} end
module.newline = function() return {type="newline"} end
module.identifier = function() return {type="identifier"} end
module.number = function() return {type="number"} end
module.operator = function(o_type, o, pred) return {type="operator",op=o,op_type=o_type,precedence=pred} end
module.parenthesis = function() return {type="parenthesis"} end

return module