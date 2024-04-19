from StyxScribe import StyxScribe

import sys, os
from pathlib import Path
os.chdir(Path(sys.argv[0]).parent)

subsume = StyxScribe("Hades2") # don't know yet what's needed here
subsume.LoadPlugins()
subsume.Launch()
