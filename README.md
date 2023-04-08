# MIT-Picture
A probabilistic programming language for visual scene perception

### Requirements
* Julia (http://julialang.org/downloads/)
* Python >= 3.7.6, < 3.8 (optinal)
* MATLAB (optional)

## Python 3.7 installation

```
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install python3.7 python3.7-dev python3.7-venv
```
## Setup virtual environment
```
python3.7 -m venv PATH_TO_VIRTUAL_ENVIRONMENT
source PATH_TO_VIRTUAL_ENVIRONMENT/bin/activate
python3.7 -m pip install -r requirements
```

## Blender installation

```
sudo add-apt-repository ppa:thomas-schiex/blender
sudo apt update
sudo apt install blender
```

### Quick Start
```python
cd <repo>/programs
julia <program-name>.jl
```
Only developers should touch the <repo>/engine folder. Any probabilistic program should reside in <repo>/programs. Please see demo programs to learn how to get started. The demo programs are quite easy to follow. Once the system is mature, I will probably put out a brief paper describing the system. Please note that this system is under heavy initial development and has a lot of known bugs. Use at your own risk. 
