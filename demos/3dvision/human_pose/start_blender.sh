#!/usr/bin/env bash
if [ "$1" == "" ]; then
    port=5000
else
    port=$1
fi
blender HumanKTH283.blend -P body_simulator_server.py --port $port
