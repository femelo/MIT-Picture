# Usage: (1) run start_blender.sh (initializes blender interface)
#		 (2) julia pose_program.jl 

# DESCRIPTION: Generative 3D human pose estimation 
# Given a single image of a human, the model will compute the most likely 3D pose. 

#include("../../../engine/picture.jl")
using Gen
using LinearAlgebra
using PyCall
using Debugger
using Sockets
import JSON
using Printf

#Note: pyimport calls are *very* slow so you are better off using something else for heavy use case.
@pyimport imageio;
@pyimport scipy as sp;
@pyimport skimage as sk;
@pyimport numpy as np;
global imread = imageio.v2.imread;
global distance_transform = sp.ndimage.distance_transform_edt;
global detect_edges = sk.feature.canny;
global invert = np.invert;
global multiply = np.multiply;
global find = np.where;

global IMAGE_COUNTER = 0
global OBSERVATIONS = Dict()
# Observed image
OBS_FNAME = ARGS[1]
# OBS_FNAME = "/home/flavio/1_Research/Probabilistic_Programming/mit-picture/demos/3dvision/human_pose/test.png"
OBS_IMAGE = imread(OBS_FNAME, as_gray=true) / 255.0;
OBS_EDGES = detect_edges(OBS_IMAGE, sigma=1.0);
# Calculate and store distance transform
observed_distance_matrix = distance_transform(invert(OBS_EDGES));
OBSERVATIONS["distance_matrix"] = observed_distance_matrix;
global VALID_INDEXES = pyeval("find(edge_map > 0)", find=find, edge_map=OBS_EDGES);
OBSERVATIONS["distance_map"] = pyeval(
	"distance_matrix[valid_indexes]",
	distance_matrix=observed_distance_matrix,
	valid_indexes=VALID_INDEXES
);
# Parameters of the likelihood function
mu = 0
sigma = 0.07

base_translation_x = -2.5992872714996340;
base_translation_z = -2.5635364055633545;
global PRIOR_PARAMETERS = Dict(
	"arm_elbow_right_rz" => Dict("type" => "uniform", "a" => 0, "b" => 360),
	"arm_elbow_right_dx" => Dict("type" => "uniform", "a" => -1, "b" => 0),
	"arm_elbow_right_dy" => Dict("type" => "uniform", "a" => -1, "b" => 1),
	"arm_elbow_right_dz" => Dict("type" => "uniform", "a" => -1, "b" => 1),
	"arm_elbow_left_rz" => Dict("type" => "uniform", "a" => 0, "b" => 360),
	"arm_elbow_left_dx" => Dict("type" => "uniform", "a" => 0, "b" => 1),
	"arm_elbow_left_dy" => Dict("type" => "uniform", "a" => -1, "b" => 1),
	"arm_elbow_left_dz" => Dict("type" => "uniform", "a" => -1, "b" => 1),
	"hip_dz" => Dict("type" => "uniform", "a" => -0.35, "b" => 0.00),
	"heel_right_dx" => Dict("type" => "uniform", "a" => -0.45, "b" => 0.10),
	"heel_right_dy" => Dict("type" => "uniform", "a" =>  0.00, "b" => 0.15),
	"heel_right_dz" => Dict("type" => "uniform", "a" => -0.20, "b" => 0.20),
	"heel_left_dx" => Dict("type" => "uniform", "a" => -0.10, "b" => 0.45),
	"heel_left_dy" => Dict("type" => "uniform", "a" =>  0.00, "b" => 0.15),
	"heel_left_dz" => Dict("type" => "uniform", "a" => -0.20, "b" => 0.20),
	"global_scale" => Dict("type" => "normal", "mu" => 1.00, "sigma" => 0.10),
	"global_translate_x" => Dict("type" => "uniform", "a" => base_translation_x - 1.0, "b" => base_translation_x + 1.0),
	"global_translate_z" => Dict("type" => "uniform", "a" => base_translation_z - 0.5, "b" => base_translation_z + 0.5),
	# "global_rotate_z" => Dict("type" => "uniform", "a" => -1, "b" => 1)
);

# Sample directory
# sample_directory = "/home/flavio/1_Research/Probabilistic_Programming/tmp"
sample_directory = ARGS[2]
if !isdir(sample_directory)
	mkdir(sample_directory)
end
# port = 5000
port = parse(Int, ARGS[3])

################### HELPER FUNCTION ###############
function arr2string(arr)
	str = "["
	for i = eachindex(arr)
		if arr[i] == "None"
			str = string(str,"\"", string(arr[i]),"\"")
		else
			str = string(str,string(arr[i]))
		end
		if i < length(arr)
			str = string(str,",")
		end
	end
	str = string(str,"]")
	return str
end
## blender interface ##
function send_to_blender(msg)
	while true
		ret = "";
		client = Nothing;
		try
			client = connect("127.0.0.1", port);
			println(client, msg);
			ret = readline(client);
			return ret
		catch y
			# Avoid printing errors
			# print(y)
		end
	end #while
end #function

function render(commands)
	for i = eachindex(commands)
		# Print ("executing ", commands[i]["cmd"], "\n")
		cmd = string("\"", commands[i]["cmd"] ,"\"");
		name = "0";
		id = string(commands[i]["id"])
		M = arr2string(commands[i]["M"])
		msg = string("{\"cmd\":", cmd, ", \"name\": ", name, ", \"id\":", id, ", \"M\":", M, "}");
		send_to_blender(msg)
	end
	# Render image
	msg = "{\"cmd\" : \"captureViewport\"}"
	fname = JSON.parse(send_to_blender(msg))
	rendering = imread(fname, as_gray=true) / 255.0
	return (rendering, fname)
end

################### PROBABILISTIC CODE ###############
@gen function generate_body_pose()	
	bone_index = Dict(
		"arm_elbow_right" => 9,
		"arm_elbow_left" => 7,
		"hip" => 1,
		"heel_left" => 37,
		"heel_right" => 29
	);

	commands = Dict();
	index = 1;

	arm_elbow_right_rz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_right_rz"]["a"],
			PRIOR_PARAMETERS["arm_elbow_right_rz"]["b"]
		),
		:arm_elbow_right_rz
	);
	commands[index] = Dict(
		"cmd" => "setBoneRotationEuler",
		"name" => 0,
		"id" => bone_index["arm_elbow_right"],
		"M" => ["None", "None", arm_elbow_right_rz]
	);
	index += 1;

	arm_elbow_right_dx = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_right_dx"]["a"],
			PRIOR_PARAMETERS["arm_elbow_right_dx"]["b"]
		),
		:arm_elbow_right_dx
	);
	arm_elbow_right_dy = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_right_dy"]["a"],
			PRIOR_PARAMETERS["arm_elbow_right_dy"]["b"]
		),
		:arm_elbow_right_dy
	);
	arm_elbow_right_dz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_right_dz"]["a"],
			PRIOR_PARAMETERS["arm_elbow_right_dz"]["b"]
		),
		:arm_elbow_right_dz
	);
	commands[index] = Dict(
		"cmd" => "setBoneLocation",
		"name" => 0,
		"id" => bone_index["arm_elbow_right"],
		"M" => [arm_elbow_right_dx, arm_elbow_right_dy, arm_elbow_right_dz]
	);
	index += 1;

	arm_elbow_left_rz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_left_rz"]["a"],
			PRIOR_PARAMETERS["arm_elbow_left_rz"]["b"]
		),
		:arm_elbow_left_rz
	)
	commands[index] = Dict(
		"cmd" => "setBoneRotationEuler",
		"name" => 0,
		"id" => bone_index["arm_elbow_left"],
		"M" => ["None", "None", arm_elbow_left_rz]
	);
	index += 1;

	arm_elbow_left_dx = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_left_dx"]["a"],
			PRIOR_PARAMETERS["arm_elbow_left_dx"]["b"]
		),
		:arm_elbow_left_dx
	);
	arm_elbow_left_dy = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_left_dy"]["a"],
			PRIOR_PARAMETERS["arm_elbow_left_dy"]["b"]
		),
		:arm_elbow_left_dy
	);
	arm_elbow_left_dz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["arm_elbow_left_dz"]["a"],
			PRIOR_PARAMETERS["arm_elbow_left_dz"]["b"]
		),
		:arm_elbow_left_dz
	);
	commands[index] = Dict(
		"cmd" => "setBoneLocation",
		"name" => 0,
		"id" => bone_index["arm_elbow_left"],
		"M" => [arm_elbow_left_dx, arm_elbow_left_dy, arm_elbow_left_dz]
	);
	index += 1;

	hip_dz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["hip_dz"]["a"],
			PRIOR_PARAMETERS["hip_dz"]["b"]
		),
		:hip_dz
	);
	commands[index] = Dict(
		"cmd" => "setBoneLocation",
		"name" => 0,
		"id" => bone_index["hip"],
		"M" => ["None", "None", hip_dz]
	);
	index += 1;

	heel_left_dx = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_left_dx"]["a"],
			PRIOR_PARAMETERS["heel_left_dx"]["b"]
		),
		:heel_left_dx
	);
	heel_left_dy = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_left_dy"]["a"],
			PRIOR_PARAMETERS["heel_left_dy"]["b"]
		),
		:heel_left_dy
	);
	heel_left_dz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_left_dz"]["a"],
			PRIOR_PARAMETERS["heel_left_dz"]["b"]
		),
		:heel_left_dz
	);
	commands[index] = Dict(
		"cmd" => "setBoneLocation",
		"name" => 0,
		"id" => bone_index["heel_left"],
		"M" => [heel_left_dx, heel_left_dy, heel_left_dz]
	);
	index += 1;

	heel_right_dx = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_right_dx"]["a"],
			PRIOR_PARAMETERS["heel_right_dx"]["b"]
		),
		:heel_right_dx
	);
	heel_right_dy = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_right_dy"]["a"],
			PRIOR_PARAMETERS["heel_right_dy"]["b"]
		),
		:heel_right_dy
	);
	heel_right_dz = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["heel_right_dz"]["a"],
			PRIOR_PARAMETERS["heel_right_dz"]["b"]
		),
		:heel_right_dz
	);
	commands[index] = Dict(
		"cmd" => "setBoneLocation",
		"name" => 0,
		"id" => bone_index["heel_right"],
		"M" => [heel_right_dx, heel_right_dy, heel_right_dz]
	);
	index += 1;

	global_scale = @trace(
		Gen.normal(
			PRIOR_PARAMETERS["global_scale"]["mu"],
			PRIOR_PARAMETERS["global_scale"]["sigma"]
		),
		:global_scale
	);
	global_translate_x = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["global_translate_x"]["a"],
			PRIOR_PARAMETERS["global_translate_x"]["b"]
		),
		:global_translate_x
	);
	global_translate_z = @trace(
		Gen.uniform(
			PRIOR_PARAMETERS["global_translate_z"]["a"],
			PRIOR_PARAMETERS["global_translate_z"]["b"]
		),
		:global_translate_z
	);
	# global_rotate_z = @trace(
	# 	Gen.uniform(
	# 		PRIOR_PARAMETERS["global_rotate_z"]["a"],
	# 		PRIOR_PARAMETERS["global_rotate_z"]["b"]
	# 	),
	# 	:global_rotate_z
	# );
	global_rotate_z = 0;

	camera = [global_scale, "None", "None", global_rotate_z, global_translate_x, "None", global_translate_z];
	commands[index] = Dict(
		"cmd" => "setGlobalAffine",
		"name" => 0,
		"id" => 0,
		"M" => camera
	);
	
	return render(commands)
end

@gen function model()
	(rendering, fname) = ({*} ~ generate_body_pose());

	edge_map = detect_edges(rendering, sigma=1.0); # edge_map = sk.feature.canny(rendering, sigma=1.0)
	edges = pyeval(
		"invert(edge_map[valid_indexes]).astype(float)",
		invert=invert,
		edge_map=edge_map,
		valid_indexes=VALID_INDEXES
	);

	# Calculate distance transform
	# distance_matrix = scp.ndimage.distance_transform_edt(~OBSERVATIONS["IMAGE"])
	# valid_indexes = find(edge_map > 0);
	# edge_map[valid_indexes] = 1e-6;
	# valid_indexes = np.where(edge_map > 0)
	# data = multiply(OBSERVATIONS["distance_matrix"][valid_indexes], edge_map[valid_indexes])

	# Generate observation
	Y = @trace(Gen.broadcasted_normal(edges .- mu, sigma), :Y);

	return Y, fname
end

function get_max_range(value, lower_bound, upper_bound)
	return min(value - lower_bound, upper_bound - value)
end

@gen function propose(trace, var_name, dispersion_factor=1.00)
	var = Symbol(var_name);
	if PRIOR_PARAMETERS[var_name]["type"] == "uniform"
		range = get_max_range(
			trace[var],
			PRIOR_PARAMETERS[var_name]["a"],
			PRIOR_PARAMETERS[var_name]["b"]
		);
		{var} ~ Gen.uniform(
			trace[var] - dispersion_factor * range,
			trace[var] + dispersion_factor * range
		)
	elseif PRIOR_PARAMETERS[var_name]["type"] == "normal"
		{var} ~ Gen.normal(
			trace[var],
			dispersion_factor * PRIOR_PARAMETERS[var_name]["sigma"]
		)
	else
		println("Variable type not defined.");
	end
end

function logmeanexp(scores)
    return logsumexp(scores) - log(length(scores))
end

function resimulation_kernel(tr, vars_groups)
	for vars_group in vars_groups
		(tr, _) = Gen.mh(tr, Gen.select(map(Symbol, vars_group)...));
	end
	return tr
end

function gibbs_kernel(tr, vars_names)
	for var_name in vars_names
		(tr, _) = Gen.mh(tr, propose, (var_name, ));
	end
	return tr
end

function do_inference()
	observation = Gen.choicemap((:Y, OBSERVATIONS["distance_map"]));
	vars = collect(keys(PRIOR_PARAMETERS));
	num_iterations = 200;
	# Initial trace
	(tr, _) = Gen.generate(model, (), observation);
	scores = Vector{Float64}(undef, num_iterations);
	for i = 1:num_iterations
		@printf("Iteration %03d", i);
		@time tr = gibbs_kernel(tr, vars);
		#@time tr = resimulation_kernel(tr, map((var) -> [var], vars));
		score = Gen.get_score(tr);
		_, fname = Gen.get_retval(tr);
		println("Log probability: ", score);
		@printf("Figure: %s\n", fname);
		scores[i] = score;
	end
	# println("Log mean probability: ", logmeanexp(scores));
end

print(string("Connecting to port ", port,"\n",))
send_to_blender("{\"cmd\" : \"setRootDir\", \"rootdir\": \"$sample_directory/\"}")

do_inference();
