#!/bin/sh
find samples/ -maxdepth 2 -mindepth 2 -type d -exec ffmpeg -framerate 30 -i {}/sample_%05d.png  {}/video.mp4 \;
