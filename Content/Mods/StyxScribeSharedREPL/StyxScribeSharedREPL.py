def Define(message=None):
    REPL = Scribe.Modules.StyxScribeREPL
    Shared = Scribe.Modules.StyxScribeShared
    Shared.Root.RunPython = Shared.Async(REPL.RunPython)

Priority = 0

def Load():
    Scribe.AddHook(Define, "StyxScribeShared: Reset", __name__)
