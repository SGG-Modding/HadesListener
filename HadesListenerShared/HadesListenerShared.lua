ModUtil.Mod.Register( "HadesListenerShared" )

local registry
local lookup
local objectData
local function getObjectData( obj, key )
	return objectData[ obj ][ key ]
end

local meta = {
	
}

local function new( id )
	local t = { }
	id = id or tonumber( ModUtil.ToString.Address( t ) )
	t.id = id
	local s = ModUtil.Proxy( t, meta )
	registry[ id ] = s
	lookup[ s ] = id
	if id > 0 then
		print( "HadesListenerShared: New: " .. id )
	end
	return s
end

local function handleNew( message )
	return new( -tonumber( message ) )
end

local function handleReset( )
	registry = { }
	lookup = setmetatable( { }, { __mode = "k" } )
	objectData = setmetatable( { }, { __mode = "k" } )
	new( 0 )
	print( "HadesListenerShared: Reset" )
end

handleReset( )
HadesListener.AddHook( handleNew, "HadesListenerShared: New: ", HadesListenerShared )