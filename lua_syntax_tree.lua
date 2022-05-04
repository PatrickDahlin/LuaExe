
--[[

	This is EBNF form of lua syntax translated into a datastructure
	Begin parsing using "chunk" then look up each index as one possible
	match. Thereafter you go through element by element and match it
	against input tokenstream.
	If a match is made, then consume token, otherwise move on to next
	optional match and if all matches have failed then we have a syntax
	error.

	Notes:
		- This is currently incomplete and only contains enough for
			variable assignment and basic expressions

		- Start parsing from "module.base" as it's the root-node
]]
local module = {}

-- Temp variables
local chunk,
	stat,
	_stat,
	laststat,
	_laststat,
	exp,
	varlist,
	explist,
	var,
	var_list_ext,
	exp_list_ext,
	binop,
	unop

-- Validator func:s, these are needed for tokens with custom content
-- 	which can only be identified by it's type
local function identifier(n) return n ~= nil and
							n.type ~= nil and
							n.type == "identifier" end

local function number(n) return n ~= nil and
							n.type ~= nil and
							n.type == "number" end

local function string(n) return n ~= nil and
							n.type ~= nil and
							n.type == "string" end

binop = {
	type = "operator",
	[1] = {{"+", terminal = true}},
	[2] = {{"-", terminal = true}},
	[3] = {{"*", terminal = true}},
	[4] = {{"/", terminal = true}},
	[5] = {{"^", terminal = true}},
	[6] = {{"%", terminal = true}},
	[7] = {{"<", terminal = true}},
	[8] = {{">", terminal = true}},
	[9] = {{"<=", terminal = true}},
	[10]= {{">=", terminal = true}},
	[11]= {{"==", terminal = true}},
	[12]= {{"and", terminal = true}},
	[13]= {{"or", terminal = true}},
}

unop = {
	type = "operator",
	[1] = {{"-", terminal = true}},
	[2] = {{"not", terminal = true}},
	[3] = {{"#", terminal = true}}
}

exp = {
	type = "expression",
	[1] = {
		{number, terminal = true, validation_func = true},
	},
	[2] = {
		{string, terminal = true, validation_func = true}
	},
	[3] = {
		{exp}, {binop}, {exp}
	},
	[4] = {
		{unop}, {exp}
	}
}

var = {
	type = "variable",
	[1] = {
		{identifier, terminal = true, validation_func = true}
	}
}

-- Temp step to include "," in the repeated var list
var_list_ext = {
	type = "varlist",
	[1] = {
		{",", terminal = true},
		{var}
	}
}

varlist = {
	type = "varlist",
	[1] = {
		{var},
		{var_list_ext, repeated = true}
	}
}

exp_list_ext = {
	[1] = {
		{exp},
		{",", terminal = true}
	}
}

explist = {
	[1] = {
		{exp_list_ext, repeated = true},
		{exp}
	}
}

stat = {
	type = "statement",
	[1] = {
		{varlist},
		{"=", terminal = true},
		{explist}
	}
}

laststat = {
	type = "statement",
	[1] = {
		{"return", terminal = true},
		{explist, optional = true}
	},
	[2] = {
		{"break", terminal = true}
	}
}

_stat = {
	type = "statement",
	[1] = {
		{stat},
		{";", optional = true, terminal = true}
	}
}

-- Extra step to include optional ";" at the end
_laststat = {
	type = "last_statement",
	[1] = {
		{laststat},
		{";", optional = true, terminal = true}
	}
}

chunk = {
	type = "chunk",
	[1] = {
		{_stat, repeated = true},
		{_laststat, optional = true}
	}
}

module.base 	= chunk
module.stat 	= stat
module.laststat = laststat
module.exp 		= exp
module.varlist 	= varlist
module.explist 	= explist
module.var		= var
module.binop	= binop
module.unop		= unop


return module