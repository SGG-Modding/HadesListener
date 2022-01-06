ModUtil.RegisterMod( "HadesListenerREPL" )

HadesListener.AddHook( function( message )
	local func, err = load ( message )
	if not func then print( err ) return end
	local ret = table.pack( pcall( func ) )
	if ret.n <= 1 then return end
	print( table.unpack( ret, 2, ret.n ) )
end, "HadesListenerREPL: " )

print( "HadesListenerREPL: Awake" )