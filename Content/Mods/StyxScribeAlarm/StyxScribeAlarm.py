import threading
import time
import os
import sys

_duration = 1
_pitch = 440

class _PingThread(threading.Thread):
    #repuposed from https://stackoverflow.com/a/57387909
    def __init__(self, name='alarm-ping-thread'):
        super(self.__class__, self).__init__(name=name)
        self.start()

    def run(self):
        #Scribe.Send("StyxScribeAlarm: Ping")
        time.sleep(2)

def _alarm(message=None):
    #https://stackoverflow.com/a/16573339
    print("StyxScribe is unresponsive!\a")

def Load():
    #start the Keyboard thread
    Scribe.AddOnRun(_PingThread, __name__)
    Scribe.AddHook(_alarm, "StyxScribeAlarm: Alarm", __name__)
    Scribe.IgnorePrefixes.append("StyxScribeAlarm: ")
