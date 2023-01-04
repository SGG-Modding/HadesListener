import threading
import time

__all__ = ["Load", "Priority", "Period", "Active", "Time", "Sent", "Recv", "Start"]

Period = 5

Active = False
Time = None
Sent = None
Recv = None
Start = time.time()

onInactive = []
thread = None

def OnInactive(callback):
    onInactive.append(callback)

class PingThread(threading.Thread):
    #repurposed from https://stackoverflow.com/a/57387909
    def __init__(self, name='ping-thread'):
        global thread
        super(__class__, self).__init__(name=name)
        thread = self
        self.start()

    active = False

    def run(self):
        global Active
        global Sent
        while True:
            self.active = False
            Sent = time.time() - Start
            Scribe.Send("StyxScribeActive: " + str(int(Sent)))
            time.sleep(Period)
            Active = self.active
            if not Active:
                for c in onInactive:
                    c()

def handlePing(message):
    global Time
    global Recv
    global Active
    thread.active = True
    Active = True
    Time = float(message)
    Recv = time.time() - Start

Priority = 0

def Load():
    #start the ping thread
    Scribe.AddOnRun(PingThread, __name__)
    Scribe.AddHook(handlePing, "StyxScribeActive: ", __name__)
    Scribe.IgnorePrefixes.append("StyxScribeActive: ")
