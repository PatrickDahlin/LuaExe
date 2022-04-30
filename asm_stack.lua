local module = {}

local function alloc(stack, size)
	local stack_obj = {}
	stack_obj.size = size
	stack_obj.index = 0
	stack_obj.offset = 0
	stack_obj.stack = stack
	stack_obj.address = function(s)
		local a = 0
		for i=1, s.index, 1 do
			a = a + s.list[i].size
		end
		return a
	end
	return stack_obj
end

module.new = function()
	local stack = {}

	stack.allocate = alloc
	stack.pointer = 0
	stack.list = {}

	--stack.dealloc = dealloc

end


return module