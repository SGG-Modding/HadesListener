ModUtil.Mod.Register( "StyxScribeAlarm" )

local runTime = _screenTime

local function alarm()
	StyxScribe.Internal.debugMode = true
	print( "StyxScribeAlarm: Alarm" )
	print( "StyxScribe is unresponsive! (" .. _screenTime - runTime .. ")" )
end

local buffer = true

local function doBuffer()
	buffer = true
end

local function checkBuffer()
	while true do
		waitScreenTime( 15 )
		if buffer == false then
			alarm( )
		end
		buffer = false
	end
end

StyxScribeAlarm.Internal = ModUtil.UpValues( function( )
	return alarm, buffer, doBuffer, checkBuffer
end )

StyxScribe.AddHook( doBuffer, "StyxScribeAlarm: Ping", StyxScribeAlarm )
thread( checkBuffer )