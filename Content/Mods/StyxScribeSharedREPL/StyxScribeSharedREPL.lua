ModUtil.Mod.Register( "StyxScribeSharedREPL" )

function StyxScribeSharedREPL.Define( )
	StyxScribeShared.Root.RunLua = StyxScribeShared.Async( StyxScribeREPL.RunLua )
end

StyxScribe.AddHook( StyxScribeSharedREPL.Define, "StyxScribeShared: Reset", StyxScribeSharedREPL )

StyxScribeSharedREPL.Define( )