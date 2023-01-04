ModUtil.Mod.Register( "StyxScribeActive" )

StyxScribeActive.Time = nil
StyxScribeActive.Local = nil
StyxScribeActive.Start = _screenTime

local function handlePing( message )
	StyxScribeActive.Time = tonumber( message )
	StyxScribeActive.Local = _screenTime
	StyxScribe.Send( "StyxScribeActive: " .. tostring( _screenTime ) )
end

StyxScribeActive.Internal = ModUtil.UpValues( function( )
	return ping
end )

StyxScribe.AddEarlyHook( handlePing, "StyxScribeActive: ", StyxScribeActive )