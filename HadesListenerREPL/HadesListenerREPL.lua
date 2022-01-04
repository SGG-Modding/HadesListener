ModUtil.RegisterMod( "HadesListenerREPL" )

HadesListener.AddHook( function( message )
	local ret
	local valid, message = pcall( load, message )
	if valid and message then
		ret = table.pack( pcall( message ) )
		if ret.n <= 1 then return end
		ModUtil.Print( table.unpack( ret, 2, ret.n ) )
	else
		ModUtil.Print( message )
	end
end, "HadesListenerREPL: " )

print( "HadesListenerREPL: Awake" )