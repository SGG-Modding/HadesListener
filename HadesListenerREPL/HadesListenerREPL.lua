ModUtil.RegisterMod( "HadesListenerREPL" )

HadesListener.AddHook( function( message )
	local func, err = load( "return " .. message )
	if not func then
		func, err = load( message )
		if not func then return print( err ) end
	end
	local ret = table.pack( pcall( func ) )
	if ret.n <= 1 then return end
	return print( table.unpack( ret, 2, ret.n ) )
end, "HadesListenerREPL: " )

print( "HadesListenerREPL: Awake" )