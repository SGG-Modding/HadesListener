ModUtil.RegisterMod( "HadesListenerREPL" )

function HadesListenerREPL.RunLua( message )
	local func, err = load( "return " .. message )
	if not func then
		func, err = load( message )
		if not func then return print( err ) end
	end
	local ret = table.pack( pcall( func ) )
	if ret.n <= 1 then return end
	return print( table.unpack( ret, 2, ret.n ) )
end

function HadesListenerREPL.RunPython( message )
	print("HadesListenerREPL: " .. message )
end

HadesListener.AddHook( HadesListenerREPL.RunLua, "HadesListenerREPL: " )