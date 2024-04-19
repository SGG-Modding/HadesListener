from StyxScribe import StyxScribe

import sys, os
from pathlib import Path
os.chdir(Path(sys.argv[0]).parent)

subsume = StyxScribe("Hades2", "Ship", [
    "VerboseScriptLogging=true",
    "DebugDraw=true",
    "DebugKeysEnabled=true",
    "RequireFocusToUpdate=false",
    ])
subsume.LoadPlugins()
subsume.Launch()
