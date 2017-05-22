#!/usr/bin/env python
import os,sys
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
            print (sample_directory)
            break
        except:
            sample_number += 1
    os.system("pkill -f \"blender.*{}\"".format(port))
    os.system("./start_blender_KTH.sh {} > /dev/null".format(port))
    os.system("julia pose_program.jl {} {} {}".format(fn, sample_directory, port))
    os.system("pkill -f \"blender.*{}\"".format(port))

if len(sys.argv) > 1:
    infer(sys.argv[1])

files = ["examples/small/{:02d}.png".format(x) for x in range(2,11)] 

for f in files:
    for p in range(5000, 5005):
        for i in range(2):
            infer(f,p)

