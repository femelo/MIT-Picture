#!/usr/bin/env python
import os,sys
import time

def infer(fn):
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
    os.system("pkill -9 blender")
    os.system("./start_blender_KTH.sh > /dev/null")
    os.system("julia pose_program.jl {} {}".format(fn, sample_directory))
    os.system("pkill -9 blender")

if len(sys.argv) > 1:
    infer(sys.argv[1])

files = ["examples/small/{:02d}.png".format(x) for x in range(11)] 

for f in files:
    for i in range(15):
        infer(f)

