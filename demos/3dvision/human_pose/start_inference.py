#!/usr/bin/env python
import os,sys,subprocess
import time

def infer(fn, port=5000):
    sample_number = 0
    try:
        os.mkdir("samples/{}".format(fn.split('/')[-1]))
    except:
        pass
    while True:
        try:
            sample_directory = "samples/{}/{:04d}".format(fn.split('/')[-1], sample_number)
            os.mkdir(sample_directory)
            os.system("cp {} {}/original.png".format(fn, sample_directory))
            print (sample_directory)
            break
        except:
            sample_number += 1
    os.system("pkill -f -9 \"blender.*{}\"".format(port))
    os.system("./start_blender_KTH.sh {} > /dev/null".format(port))
    os.system("julia pose_program.jl {} {} {}".format(fn, sample_directory, port))
    os.system("pkill -f -9 \"blender.*{}\"".format(port))

if len(sys.argv) > 1:
    infer(sys.argv[1])

def thread_run(port):
    while True:
        files = ["examples/small/{:02d}.png".format(x) for x in [12, 0, 4, 7, 8, 11]] 

        for f in files:
            for i in range(1):
                infer(f,port)

import threading
threads = []
our_pid = os.getpid()
other_pids = set(map(int, subprocess.check_output("pgrep -f start_inference.py", shell=True).split(b"\n")[:-1]))
other_pids.remove(our_pid)

if other_pids: os.system("kill -9 {}".format(" ".join(map(str, other_pids))))
os.system("pkill -9 -f \"julia pose\"")
os.system("pkill -9 blender")
for p in range(5000, 5003):
    t = threading.Thread(target=thread_run, args=(p,))
    threads.append(t)
    t.start()


