from styxscribe import StyxScribe

import sys, os
from pathlib import Path
os.chdir(Path(sys.argv[0]).parent)

subsume = StyxScribe("Pyre")
subsume.LoadPlugins()
subsume.Launch()
