#!/bin/bash
dirs=$(find samples/ -maxdepth 2 -mindepth 1 -type d)

for dir in $dirs; do
    ffmpeg -framerate 30 -i $dir/%06d.png  $dir/video.mp4;
done
