import threading
import time
import os
import sys

_duration = 1
_pitch = 440
_runtime = None

class _PingThread(threading.Thread):
    #repuposed from https://stackoverflow.com/a/57387909
    def __init__(self, name='alarm-ping-thread'):
        super(self.__class__, self).__init__(name=name)
        self.start()

    def run(self):
        while True:
            Scribe.Send("StyxScribeAlarm: Ping")
            time.sleep(10)

def _onrun():
    global _runtime
    _runtime = time.time()
    _PingThread()

def _alarm(message=None):
    #https://stackoverflow.com/a/16573339
    print(f"StyxScribe is unresponsive! ({time.time()-_runtime})\a")

Priority = 0

def Load():
    #start the Keyboard thread
    Scribe.AddOnRun(_onrun, __name__)
    Scribe.AddHook(_alarm, "StyxScribeAlarm: Alarm", __name__)
    Scribe.IgnorePrefixes.append("StyxScribeAlarm: ")
