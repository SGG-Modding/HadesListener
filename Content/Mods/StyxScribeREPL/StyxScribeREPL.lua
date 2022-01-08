ModUtil.Mod.Register( "StyxScribeREPL" )

function StyxScribeREPL.RunLua( message )
	local func, err = load( "return " .. message )
	if not func then
		func, err = load( message )
		if not func then return print( err ) end
	end
	local ret = table.pack( pcall( func ) )
	if ret.n <= 1 then return end
	return ModUtil.Print( ModUtil.Args.Map( ModUtil.ToString.Value, table.unpack( ret, 2, ret.n ) ) )
end

function StyxScribeREPL.RunPython( message )
	print("StyxScribeREPL: " .. message )
end

StyxScribe.AddHook( StyxScribeREPL.RunLua, "StyxScribeREPL: ", StyxScribeREPL )