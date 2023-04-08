#Picture : Unit tests
include("torch_interface.jl")
using Torch
Torch.load_torch_script("test.lua")
Torch.call("get_samples", 1)