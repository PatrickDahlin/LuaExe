local module = {}

module.compile = function(ast, outname)
	-- ast.nodes contains all statements
	-- ast.variables for all variables used
	-- ast.constants for all constant values (currently only numbers)

	-- step through all statements
	-- for each one, break them down to single operations
	-- output said operations as assembly

	

end

return module