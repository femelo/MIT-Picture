# Usage: (1) run start_blender_KTH.sh (initializes blender interface)
#		 (2) julia pose_program.jl 

# DESCRIPTION: Generative 3D human pose estimation 
# Given a single image of a human, the model will compute the most likely 3D pose. 

include("../../../engine/picture.jl")
using Debug
import JSON

#Note: pyimport calls are *very* slow so you are better off using something else for heavy use case.
@pyimport scipy.misc as scpy; @pyimport skimage.feature as edge
@pyimport scipy.ndimage.morphology as scp_morph; @pyimport numpy as np

global IMAGE_COUNTER = 0
OBSERVATIONS=Dict()
OBS_FNAME = ARGS[1] #observed image
OBS_IMAGE = int(scpy.imread(OBS_FNAME,true))/255.0
OBS_IMAGE = edge.canny(OBS_IMAGE, sigma=1.0)
#calculate and store distance transform 
dist_obs = pyeval("dt(npinvert(im))", npinvert=np.invert, dt=scp_morph.distance_transform_edt, im=OBS_IMAGE)
OBSERVATIONS["dist_obs"] = dist_obs

#Many iterations
sample_directory = ARGS[2]
#sample_directory = string("samples_", split(OBS_FNAME, '/')[end], "_", sample_number,)
#mkdir(sample_directory)
mkdir(sample_directory * "/tmp/")

################### HELPER FUNCTION ###############
function arr2string(arr)
	str = "["
	for i=1:length(arr)
		if arr[i] == None
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
		ret = ""
		client = null
		try
			client = connect(5000)
			println(client,msg)
			ret = readline(client)
			return ret
		catch y
			1
		end
	end #while
end #function

function render(CMDS)
	for i=1:length(CMDS)
		#print ("executing ", CMDS[i]["cmd"], "\n")
		cmd = string("\"", CMDS[i]["cmd"] ,"\"");
		name = "0";
		id = string(CMDS[i]["id"])
		M = arr2string(CMDS[i]["M"])
		msg = string("{\"cmd\":", cmd, ", \"name\": ", name, ", \"id\":", id, ", \"M\":",M,"}");
		send_to_blender(msg)
	end
	#render image
	#print("Rendering\n")
	msg = "{\"cmd\" : \"captureViewport\"}"
	fname = JSON.parse(send_to_blender(msg))
	rendering = int(scpy.imread(fname))/255.0
	return rendering
end

################### PROBABILISTIC CODE ###############
function PROGRAM()	
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int)
	
	bone_index = {"arm_elbow_R" => 9, "arm_elbow_L" => 7, "hip" => 1, "heel_L" => 37, "heel_R" => 29};

	CMDS = Dict(); cnt=1;

	arm_elbowR_rz = block("arm_elbowR_rz", Uniform(0,360,1,1))
	CMDS[cnt]={"cmd"=>"setBoneRotationEuler", "name"=>0, "id"=>bone_index["arm_elbow_R"], "M"=>[None,None,arm_elbowR_rz]};cnt+=1;

	arm_elbowR_dx = block("arm_elbowR_dx", Uniform(-1,0,1,1))
	arm_elbowR_dy = block("arm_elbowR_dy", Uniform(-1,1,1,1))
	arm_elbowR_dz = block("arm_elbowR_dz", Uniform(-1,1,1,1))
	CMDS[cnt]={"cmd"=>"setBoneLocation", "name"=>0, "id"=>bone_index["arm_elbow_R"], "M"=>[arm_elbowR_dx,arm_elbowR_dy,arm_elbowR_dz]};cnt+=1;

	arm_elbowL_rz = block("arm_elbowL_rz", Uniform(0,360,1,1))
	CMDS[cnt]={"cmd"=>"setBoneRotationEuler", "name"=>0, "id"=>bone_index["arm_elbow_L"], "M"=>[None,None,arm_elbowL_rz]};cnt+=1;

	arm_elbowL_dx = block("arm_elbowL_dx", Uniform(0,1,1,1))
	arm_elbowL_dy = block("arm_elbowL_dy", Uniform(-1,1,1,1))
	arm_elbowL_dz = block("arm_elbowL_dz", Uniform(-1,1,1,1))
	CMDS[cnt]={"cmd"=>"setBoneLocation", "name"=>0, "id"=>bone_index["arm_elbow_L"], "M"=>[arm_elbowL_dx,arm_elbowL_dy,arm_elbowL_dz]};cnt+=1;

	hip_dz = block("hip_dz", Uniform(-0.35,0,1,1))
	CMDS[cnt]={"cmd"=>"setBoneLocation", "name"=>0, "id"=>bone_index["hip"], "M"=>[None,None,hip_dz]};cnt+=1;

	heel_L_dx = block("heel_L_dx", Uniform(-0.1,0.45,1,1))
	heel_L_dy = block("heel_L_dy", Uniform(0,0.15,1,1))
	heel_L_dz = block("heel_L_dz", Uniform(-0.2,0.2,1,1))
	CMDS[cnt]={"cmd"=>"setBoneLocation", "name"=>0, "id"=>bone_index["heel_L"], "M"=>[heel_L_dx,heel_L_dy,heel_L_dz]};cnt+=1;

	heel_R_dx = block("heel_R_dx", Uniform(-0.45,0.1,1,1))
	heel_R_dy = block("heel_R_dy", Uniform(0,0.15,1,1))
	heel_R_dz = block("heel_R_dz", Uniform(-0.2,0.2,1,1))
	CMDS[cnt]={"cmd"=>"setBoneLocation", "name"=>0, "id"=>bone_index["heel_R"], "M"=>[heel_R_dx,heel_R_dy,heel_R_dz]};cnt+=1;

	global_scale = block("global_scale", Normal(0.98,0.01,1,1))
	global_translate_x = block("global_translate_x", Uniform(-2.599287271499634-1,-2.599287271499634+1,1,1))
	global_translate_z = block("global_translate_z", Uniform(-2.5635364055633545,-2.5635364055633545+0.5,1,1))
	global_rotate_z = 0#Uniform(-1,1,1,1)

	camera = [global_scale, None, None, global_rotate_z, global_translate_x, None, global_translate_z]
	CMDS[cnt]={"cmd"=>"setGlobalAffine", "name"=>0, "id"=>0, "M"=>camera};cnt+=1;

	rendering = render(CMDS)

	edgemap = pyeval("canny(rendering,1.0)", canny = edge.canny, rendering=rendering) #edgemap = edge.canny(rendering, sigma=1.0)

	#calculate distance transform
	# dist_obs = scp_morph.distance_transform_edt(~OBSERVATIONS["IMAGE"])
	valid_indxs = pyeval("npwhere(edgemap>0)", npwhere=np.where,edgemap=edgemap)
	#valid_indxs = np.where(edgemap > 0)
	D = pyeval("npmultiply(dist_obs[valid_indxs], ren[valid_indxs])",npmultiply=np.multiply, dist_obs=OBSERVATIONS["dist_obs"],valid_indxs=valid_indxs, ren=edgemap)

	#constraint to observation
	observe(0,Normal(0,0.35),D)

	return rendering
end

########### USER DIAGNOSTICS ##############
function debug_callback(TRACE)
	global IMAGE_COUNTER
	println("LOGL=>", TRACE["ll"])
	scpy.imsave(string(sample_directory * "/sample_",lpad(IMAGE_COUNTER, 5, 0),".png",), TRACE["PROGRAM_OUTPUT"])
	open(string(sample_directory * "/trace_",lpad(IMAGE_COUNTER, 5, 0),".txt",), "a") do f
		d = deepcopy(TRACE["RC"])
		d["LOGL"] = TRACE["ll"]
		write(f, JSON.json(d))
	end
	IMAGE_COUNTER += 1
end

send_to_blender("{\"cmd\" : \"setRootDir\", \"rootdir\": \"$sample_directory/tmp/\"}")

load_program(PROGRAM)
load_observations(OBSERVATIONS)
init()
#run basic inference by cycling through all variables 
infer(debug_callback,5000,"CYCLE")


