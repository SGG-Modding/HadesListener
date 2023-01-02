ModUtil.Mod.Register( "StyxScribeShared" )

local delim = '¦'
local newline = '¶'

local lookup
local registry
local promises
local objectData

local encode
local decode
local marshall

local ready = false
local classes = { }
local marshallTypes = { }
local marshallTypesOrder = { }

local None = { }
ModUtil.Identifiers.Data[ None ] = "StyxScribeShared.None"

local function nop( ... ) return ... end

local function typeCall( m, f )
	local f = f or function( cls, ... )
		return cls:_new( ... )
	end
	local mm = getmetatable( m ) or { }
	mm.__call = f
	return setmetatable( m, mm )
end

local function marshallType( ... )
	local types = table.pack( ... )
	local m = table.remove( types )
	table.insert( marshallTypesOrder, m )
	for _, t in ipairs( types ) do
		mt = marshallTypes[ m ] or { }
		table.insert( mt, t )
		marshallTypes[ m ] = mt
	end
	return m
end

-- mirror the structure of the python classes as metatables (mostly)
local function class( name, ... )
	local metas = table.pack( ... )
	local n = metas.n
	local m = metas[ n ]
	for i = n - 1, 1, -1 do
		metas[ i + 1 ] = metas[ i ]
	end
	metas[ 1 ] = m
	local meta = { }
	for i = n, 1, -1 do
		for k, v in pairs( metas[ i ] ) do
			meta[ k ] = v
		end
	end
	if name ~= nil then
		meta._name = name
		classes[ name ] = meta
	end
	meta._parents = { table.unpack( metas, 2, n ) }
	return meta
end

local function new( m, ... )
	return m:_new( ... )
end

local _table = {
	_new = function( )
		return { }
	end
}

local _function = {
	_new = function( )
		return nop
	end
}

local Proxy = {
	_proxy = true,
	__gc = function( s )
		local data = objectData[ s ]
		if data ~= nil then
			data[ "alive" ] = false
		end
		local i = lookup[ s ]
		if i ~= nil then
			lookup[ s ] = nil
			if i ~= 0 then
				registry[ i ] = nil
				StyxScribe.Send( "StyxScribeShared: Del: " .. tostring( i ) )
			end
		end
		
	end,
	_new = function( m, ... )
		local s = setmetatable( { }, m )
		return (m._init or nop)( s, ... )
	end,
	_init = function( s, v, i )
		local meta = getmetatable( s )
		i = i or tonumber( ModUtil.ToString.Address( s ), 16 )
		local data = { }
		objectData[ s ] = data
		data.proxy = meta:_newproxy( )
		data[ "alive" ] = true
		registry[ i ] = s
		lookup[ s ] = i
		data[ "root" ] = i == 0
		data[ "local" ] = i > 0
		if data[ "local" ] then
			StyxScribe.Send( "StyxScribeShared: New: " .. meta._name .. delim .. i )
		end
		if v then
			meta._marshall( s, v )
		end
		return s
	end,
	__tostring = function( s )
		local name = objectData[ s ].name
		name = name and name .. ': ' or ""
		return name .. getmetatable( s )._name .. ': ' .. ModUtil.ToString.Address( s ) 
	end
}

local ProxySet = class( nil, Proxy, {
	_shset = function( s, k, v )
		local i = tostring( lookup[ s ] )
		k = encode( k )
		v = encode( v )
		StyxScribe.Send( "StyxScribeShared: Set: " .. i .. delim .. k .. delim .. v )
	end,
	_marshall = function( s, obj )
		for k, v in pairs( obj ) do
			s[ k ] = v
		end
	end,
	_newproxy = function( m )
		return { }
	end
} )

local ProxyCall = class( nil, Proxy, {
	_marshall = function( s, f )
		objectData[ s ].proxy = f
	end,
	_newproxy = function( m )
		return nop
	end
} )

local Table = marshallType( "table", typeCall( class( "Table", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		objectData[ s ].proxy[ k ] = v
		local meta = getmetatable( s )
		if sync ~= false then
			meta._shset( s, k, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ].proxy[ k ]
	end,
	__len = function( s )
		return #objectData[ s ].proxy
	end,
	__next = function( s, ... )
		return next( objectData[ s ].proxy, ... )
	end,
	__inext = function( s, ... )
		return inext( objectData[ s ].proxy, ... )
	end,
	__pairs = function( s, ... )
		return pairs( objectData[ s ].proxy, ... )
	end,
	__ipairs = function( s, ... )
		return ipairs( objectData[ s ].proxy, ... )
	end
} ) ) )

local Array = marshallType( "table", typeCall( class( "Array", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		local proxy = objectData[ s ].proxy
		local n = #proxy
		if type( k ) ~= "number" or math.floor( k ) ~= k then
			error( "Array index must be an integer" , 2 )
		end
		if k > n + 1 or k < 1 then
			error( "Array index " .. tostring( k ) .." out of bounds" , 2 )
		end
		proxy[ k ] = v
		local meta = getmetatable( s )
		if sync ~= false then
			meta._shset( s, k - 1, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ].proxy[ k ]
	end,
	__len = function( s )
		return #objectData[ s ].proxy
	end,
	__next = function( s, ... )
		return inext( objectData[ s ].proxy, ... )
	end,
	__inext = function( s, ... )
		return inext( objectData[ s ].proxy, ... )
	end,
	__pairs = function( s, ... )
		return ipairs( objectData[ s ].proxy, ... )
	end,
	__ipairs = function( s, ... )
		return ipairs( objectData[ s ].proxy, ... )
	end
} ) ) )

local Args = marshallType( "table", typeCall( class( "Args", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		local proxy = objectData[ s ].proxy
		local n = proxy.n or #proxy
		if k == 'n' then
			if v < n then
				for i = v + 1, n, 1 do
					proxy[ i ] = nil
				end
			end
		else
			if type( k ) ~= "number" or math.floor( k ) ~= k then
				error( "Args index must be an integer" , 2 )
			end
			if k < 1 then
				error( "Args index " .. tostring( k ) .." out of bounds" , 2 )
			end
			if k >= n then
				proxy.n = k
			end
		end
		proxy[ k ] = v
		local meta = getmetatable( s )
		if sync == nil or sync then
			meta._shset( s, k ~= 'n' and k - 1 or k, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ].proxy[ k ]
	end,
	__len = function( s )
		return objectData[ s ].proxy[ 'n' ]
	end,
	__next = function( s, ... )
		return next( objectData[ s ].proxy, ... )
	end,
	__inext = function( s, ... )
		local data = objectData[ s ]
		local k, v = next( data.proxy, ... )
		if k == 'n' then
			k, v = next( objectData[ s ].proxy, k )
		end
		return k, v
	end,
	__pairs = function( s, ... )
		return pairs( objectData[ s ].proxy, ... )
	end,
	__ipairs = function( s, ... )
		return qrawipairs( objectData[ s ].proxy, ... )
	end
} ), function( cls, ... ) return cls:_new( ... ) end ) )

local KWArgs = marshallType( "table", typeCall( class( "KWArgs", Table, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		objectData[ s ].proxy[ k ] = v
		local meta = getmetatable( s )
		if sync ~= false then
			if type( k ) == "number" then
				k = k - 1
			end
			meta._shset( s, k, v )
		end
	end
} ) ) )

local Action = marshallType( "function", typeCall( class( "Action", ProxyCall, {
	__call = function( s, ... )
		local data = objectData[ s ]
		if data[ "local" ] then
			return data.proxy( ... )
		end
		local i = tostring( lookup[ s ] )
		local a = Args( table.pack( ... ) )
		local ai = tostring( lookup[ a ] )
		StyxScribe.Send( "StyxScribeShared: Act: " .. i .. delim .. ai )
	end,
	_call = function( s, args )
		return s( table.unpack( args ) )
	end
} ) ) )

local KWAction = typeCall( class( "KWAction", Action, { 
	__call = function( s, kwargs )
		local data = objectData[ s ]
		if data[ "local" ] then
			return data.proxy( kwargs )
		end
		local i = tostring( lookup[ s ] )
		local a = KWArgs( kwargs )
		local ai = tostring( lookup[ a ] )
		StyxScribe.Send( "StyxScribeShared: Act: " .. i .. delim .. ai )
	end,
	_call = function( s, args )
		return s( args )
	end
} ) )

local Relay = typeCall( class( "Relay", Action, {
	__call = function( s, call, ... )
		local _call = getmetatable( s )._parents[ 1 ].__call
		if objectData[ s ][ "local" ] then
			return call( _call( s, ... ) )
		end
		return _call( s, call, ... )
	end
} ) )

local KWRelay = typeCall( class( "KWRelay", KWAction, { 
	__call = function( s, kwargs )
		local _call = getmetatable( s )._parents[ 1 ].__call
		if objectData[ s ][ "local" ] then
			local call = kwargs[ 1 ]
			local n = #kwargs
			kwargs = KWArgs( kwargs )
			for i = 1, n, 1 do
				kwargs[ i ] = kwargs[ i + 1 ]
			end
			return call( _call( s, kwargs ) )
		end
		return _call( s, kwargs )
	end,
} ) )

local _Async__call = function( s, ... )
	local _call = getmetatable( s )._parents[ 1 ].__call
	if objectData[ s ][ "local" ] then
		return _call( s, ... )
	end
	local p = Table()
	p.Done = false
	p.Rets = nil
	local i = lookup[ s ]
	local pi = lookup[ p ]
	StyxScribe.Send( "StyxScribeShared: Async: " .. i .. delim .. pi )
	_call( s, ... )
	return p
end

local Async = typeCall( class( "Async", Action, {
	__call = _Async__call
} ) )

local KWAsync = typeCall( class( "KWAsync", KWAction, { 
	__call = _Async__call
} ) )

local function newLazy( cls, f, ... )
	if ModUtil.Callable( f ) then
		local obj = cls:_new( )
		return obj( f, ... )
	end
	return cls:_new( f, ... )
end

local _Lazy__call = function( s, f, ... )

	if s.Done then
		local rets = s.Rets
		local meta = getmetatable(rets)
		if meta == Args then
			return table.unpack( rets )
		end
		return rets
	end

	local meta = getmetatable( s )
	local data = objectData[ s ]
	local rets

	if data[ "local" ] and f ~= nil then
		s.Func = f
		s.Args = meta._args( s, ... )
		local fmeta = getmetatable( f )
		local fdata = objectData[ f ]
		if fmeta and fmeta._call and fdata and not fdata[ "local" ] then
			s.Done = false
			s.Rets = nil
			return s
		end
		rets = f( ... )
	else
		f = s.Func
		local fmeta = getmetatable( f )
		if fmeta then
			rets = table.pack( fmeta._call( f, s.Args ) )
		else
			rets = table.pack( f( table.unpack( s.Args ) ) )
		end
	end
	if rets.n == 0 then
		s.Rets = None
	elseif rets.n == 1 then
		s.Rets = rets[ 1 ]
	else
		s.Rets = Args( rets )
	end
	s.Done = true
	return table.unpack( rets )
end

local Lazy = typeCall( class( "Lazy", Table, {
	__call = _Lazy__call,
	_lazy = true,
	_args = function( s, ... )
		return Args( table.pack( ... ) )
	end
} ), newLazy )

local KWLazy = typeCall( class( "KWLazy", Table, { 
	__call = _Lazy__call,
	_lazy = true,
	_args = function( s, kwargs )
		return KWArgs( kwargs )
	end
} ), newLazy )


--https://stackoverflow.com/a/60172017
local function split( str, pat, limit )
	local t = { }
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find( fpat, 1 )
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert( t, cap )
		end

		last_end = e + 1
		s, e, cap = str:find( fpat, last_end )

		if limit ~= nil and limit <= #t then
			break
		end
	end

	if last_end <= #str then
		cap = str:sub( last_end )
		table.insert( t, cap )
	end

	return t
end

local function marshaller( obj )
	local m = getmetatable( obj )
    if m and m._proxy then return end
	local t = type( obj )
    for _, m in ipairs( marshallTypesOrder ) do
		for _, _t in pairs( marshallTypes[ m ] ) do
			if t == _t then
				return m
			end
		end
	end
end

function marshall( obj )
    if obj == None then return nil end
    local m = marshaller( obj )
    if m then return new( m, obj ) end
    if type( obj ) == "string" then
        return obj:gsub( delim, ':' )
	end
    return obj
end

function decode( s )
	local t, v = s:sub(1,1), s:sub(2)
	if t == '*' then return nil end
	if t == '&' then return v:gsub( newline, '\n' ) end
	if t == '#' then return tonumber( v ) end
	if t == '@' then return registry[ -tonumber( v ) ] end
	if t == '!' then return v == "!" end
	error( s .. " cannot be decoded.", 2 )
end

function encode( v )
	if v == nil or v == None or v == NULL then return "*" end
	local t, m = type( v ), getmetatable( v )
	if t == "string" then return "&" .. v:gsub( '\n', newline ) end
	if t == "number" then return "#" .. tostring( v ) end
	if m and m._proxy then return "@" .. tostring( lookup[ v ] ) end
	if t == "boolean" then return v and "!!" or "!" end
	error( tostring( v ) .. " cannot be encoded.", 2 )
end

local function handleNew( message )
	if not ready then return end
	local name, id = table.unpack( split( message, delim ) )
	return new( classes[ name ], nil, -tonumber( id ) )
end

local function handleDel( message )
	if not ready then return end
	local id = -tonumber( message )
	local obj = registry[ id ]
	if obj ~= nil then
		objectData[ obj ][ "alive" ] = false
		registry[ id ] = nil
	end
end

local function handleSet( message )
	if not ready then return end
	local id, key, value = table.unpack( split( message, delim ) )
	local obj = registry[ -tonumber( id ) ]
	key = decode( key )
	value = decode( value )
	local meta = getmetatable( obj )
	local vmeta = getmetatable( value )
	if vmeta and vmeta._lazy then
		value = value( )
		return meta.__newindex( obj, key, value, true )
	end
	return meta.__newindex( obj, key, value, false )
end

local function handleAct( message )
	if not ready then return end
	local func, args = table.unpack( split( message, delim ) )
	func = -tonumber( func )
	local prom = promises[ func ]
    func = registry[ func ]
    args = registry[ -tonumber( args ) ]
    local rets = table.pack( getmetatable(func)._call( func, args ) )
	if prom then 	
		if rets.n == 0 then
			prom.Rets = None
		elseif rets.n == 1 then
			prom.Rets = rets[ 1 ]
		else
			prom.Rets = Args( rets )
		end
		prom.Done = true
	end
end

local function handleAsync( message )
	if not ready then return end
	local f, p = table.unpack( split( message, delim ) )
	f = -tonumber( f )
	p = registry[ -tonumber( p ) ]
	promises[ f ] = p
end

local function handleName( message )
	if not ready then return end
	local id, name = table.unpack( split( message, delim ) )
	local obj = registry[ -tonumber( id ) ]
	objectData[ obj ].name = decode( name )
end

local function handlePyReset( )
	ready = true
	StyxScribe.Send( "StyxScribeShared: Reset" )
end

local function handleLuaReset( )
	ready = false
	registry = { }
	lookup = setmetatable( { }, { __mode = "k" } )
	promises = { }
	objectData = setmetatable( { }, { __mode = "k" } )
	StyxScribeShared.Root = Table( nil, 0 )
	StyxScribe.Send( "StyxScribeShared: Reload" )
end

function StyxScribeShared.IsLocal( proxy )
	return objectData[ proxy ][ "local" ]
end

function StyxScribeShared.GetID( proxy )
	return lookup[ proxy ]
end

function StyxScribeShared.GetName( proxy )
	return objectData[ proxy ].name
end

function StyxScribeShared.SetName( proxy, name )
	objectData[ proxy ].name = name
	local id = tostring( lookup[ proxy ] )
	StyxScribe.Send( "StyxScribeShared: Name: " .. id .. delim .. encode( name ) )
end

StyxScribeShared.Internal = ModUtil.UpValues( function( )
	return registry, lookup, delim, newline, objectData, split, class, new, nop,
		marshallType, marshallTypes, marshaller, marshall, _table, _function,
		Proxy, ProxySet, ProxyCall, typeCall, decode, encode, ready, promises,
		handlePyReset, handleLuaReset, handleName, handleNew, handleSet, handleAct, handleDel, handleAsync,
		None, Table, Array, Args, KWArgs, Action, KWAction, Relay, KWRelay, Async, KWAsync, Lazy, KWLazy
end )

ModUtil.Table.Merge( StyxScribeShared, {
	None = None, Table = Table, Array = Array,
	Args = Args, KWArgs = KWArgs, Action = Action, KWAction = KWAction,
	Relay = Relay, KWRelay = KWRelay, Async = Async, KWAsync = KWAsync, Lazy = Lazy, KWLazy = KWLazy
} )

StyxScribe.AddHook( handlePyReset, "StyxScribeShared: Reset", StyxScribeShared )
StyxScribe.AddHook( handleName, "StyxScribeShared: Name: ", StyxScribeShared )
StyxScribe.AddHook( handleNew, "StyxScribeShared: New: ", StyxScribeShared )
StyxScribe.AddHook( handleSet, "StyxScribeShared: Set: ", StyxScribeShared )
StyxScribe.AddHook( handleDel, "StyxScribeShared: Del: ", StyxScribeShared )
StyxScribe.AddHook( handleAct, "StyxScribeShared: Act: ", StyxScribeShared )
StyxScribe.AddHook( handleAsync, "StyxScribeShared: Async: ", StyxScribeShared )
handleLuaReset( )