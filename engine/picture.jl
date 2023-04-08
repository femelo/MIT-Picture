
# module Picture

if isdefined(Base, :Params) == false
	mutable struct Params
		PROGRAM
		TRACE_EXTERN
		TRACE
		NEW_TRACE
		CURRENT_TRACE
		LOOP_LIST
		TAST
		OBSERVATIONS
		USER_DEFINED
		TAPE
	end
end

global parameters = Params(NaN, NaN, Dict(), Dict(), Dict(), Dict(), NaN, NaN, Dict(), Dict())

global GRADIENT_CALC = false


using Distributions
using Debugger
using DataStructures

using PyCall
@pyimport numpy as np
@pyimport matplotlib.pyplot as plt
@pyimport opendr.util_tests as util_tests
@pyimport chumpy as ch
@pyimport opendr.simple as odr
@pyimport numpy.random as npr
@pyimport math as pmath
@pyimport scipy.misc as scpy
@pyimport gc as garbage
chumpy_lib = pyimport(:chumpy)


garbage.disable()

include("erps.jl")
include("codetransform.jl")
include("proposals.jl")
include("hmc.jl")
include("optimize.jl")
include("mcmcML.jl")
include("elliptical.jl")
include("torch_interface.jl")
include("gibbs_kernel.jl")
# @debug begin 

#################### GLOBAL STRUCTURES ###################
# global TRACE = Dict()
# global NEW_TRACE = Dict()
# global CURRENT_TRACE = Dict()

# global LOOP_LIST = Dict()

# AST = NaN
# TAST = NaN


#################### HELPER FUNCTIONS ####################
#Appending to arrays
myappend(v::Vector{T}, x::T) where {T} = [v..., x]


function check_if_random_choice(expression)
	str_exp = string(expression)
	# if search(str_exp,"observe") != 0:-1
	if occursin("observe", str_exp)
		return false
	end
	
	# if search(str_exp, "block") != 0:-1
	if occursin("block", str_exp)
		return true
	end

	# if search(str_exp, "memoize") != 0:-1
	if occursin("memoize", str_exp)
		return true
	end

	# try check_block = string(expression.args[2].args[1])
	# 	if check_block == "block"
	# 		return true
	# 	end
	# catch
	# 	ret = false
	# end

	local ret = false
	try	input_erp = string(expression.args[2].args[1]) #string(expression.args[2].args[2].args[2].args[1])
		ERPS = ["DiscreteUniform", "Bernoulli","Beta","Poisson", "Uniform","Normal","Multinomial", "Gamma", "MvNormal"]
		
		for i=eachindex(ERPS)
			#ret = ret | (match(Regex(ERPS[i]),expression) != Nothing())
			ret = ret | (ERPS[i] == input_erp)
			if ret == true
				return ret
			end
		end
	catch
		ret = false
	end

	return ret
end


function is_theta_equal(theta_c, theta_d) #theta_c can have symbols
	equal = false

	for ii=eachindex(theta_c)
		if typeof(theta_c[ii]) == Symbol
			theta_c[ii] = eval(theta_c[ii])
		end
		equal += (theta_c[ii] == theta_d[ii])
	end
	return equal
end

function trace_update(TAST)

	parameters.CURRENT_TRACE["ll"] = 0; parameters.CURRENT_TRACE["ll_fresh"] = 0; parameters.CURRENT_TRACE["ll_stale"] = 0;
	parameters.CURRENT_TRACE["ACTIVE_K"] = Dict()

	parameters.CURRENT_TRACE["PROGRAM_OUTPUT"] = eval(TAST[1].code)

	all_choices = unique(append!(collect(keys(parameters.CURRENT_TRACE["RC"])),collect(keys(parameters.CURRENT_TRACE["ACTIVE_K"]))))
	for name in all_choices
		if haskey(parameters.CURRENT_TRACE["ACTIVE_K"], name) == false #inactive
			ERP = parameters.CURRENT_TRACE["RC"][name]["ERP"]
			theta_d = parameters.CURRENT_TRACE["RC"][name]["theta_c"]
			VAL = parameters.CURRENT_TRACE["RC"][name]["X"]
			parameters.CURRENT_TRACE["ll_stale"]+=logscore_erp(ERP_CREATE(ERP,theta_d),VAL, theta_d)
			delete!(parameters.CURRENT_TRACE,name)
		end
	end

	if parameters.CURRENT_TRACE["PROGRAM_OUTPUT"] == "OVERFLOW_ERROR"
		parameters.CURRENT_TRACE["ll"]=-1e200
	end
end

function load_program(PROGRAM)
	parameters.PROGRAM = PROGRAM
end

function load_observations(OBSERVATIONS)
	parameters.OBSERVATIONS = OBSERVATIONS
end

function initialize_trace_extern(funcFtr,args)
	parameters.TRACE_EXTERN = funcFtr(args)
end

function init()
	AST=code_lowered(parameters.PROGRAM, ())
	#AST=code_lowered(PROGRAM,(Dict{Any,Any},))
	parameters.TAST = transform_code(AST)

	parameters.TRACE["RC"]=Dict()
	parameters.TRACE["observe"]=Dict()

	parameters.CURRENT_TRACE = deepcopy(parameters.TRACE)
	trace_update(parameters.TAST)
	parameters.TRACE = deepcopy(parameters.CURRENT_TRACE)
end


function observe_iid(trc,tag,input, output)
	trc.OBSERVATIONS = ["input"=>input, "output"=>output]
end


function trace(PROGRAM, args)
	parameters.OBSERVATIONS = args
	parameters.PROGRAM = PROGRAM
	AST=code_lowered(parameters.PROGRAM,())
	#AST=code_lowered(PROGRAM,(Dict{Any,Any},))
	parameters.TAST = transform_code(AST)

	parameters.TRACE["RC"]=Dict()
	parameters.TRACE["observe"]=Dict()

	parameters.CURRENT_TRACE = deepcopy(parameters.TRACE)
	trace_update(parameters.TAST)
	parameters.TRACE = deepcopy(parameters.CURRENT_TRACE)
	return parameters
end


function infer(debug_callback="", iterations = 100, group_name="", inference="MH_SingleSite", args="",mode="")
	println("Starting Inference [Scheme=",inference,"]")
	ll = parameters.TRACE["ll"];
	for iters=1:iterations
		if iters%50 == 0
			println("Iter#: ",iters)
		end
		rv_choices = collect(keys(parameters.TRACE["RC"]))
		if group_name == ""
			#select random f_k via its name
			idx=rand(1:length(parameters.TRACE["RC"]))
			chosen_rv = [rv_choices[idx]]
		else
			if group_name == "CYCLE" #reserved name for cycling through all variables
				indx = iters%length(rv_choices)
				indx = indx + 1
				chosen_rv = [rv_choices[indx]]
			else
				chosen_rv = [group_name]
			end
		end
		########## Metropolis Hastings ##########
		# println("CHOSEN:", chosen_rv)
		if inference == "MH" || inference == "MH_SingleSite"
			if typeof(chosen_rv) == Array{ASCIIString,1}
				chosen_rv = chosen_rv[1]
				new_X,new_logl, F, R = sample_from_proposal(parameters.TRACE,chosen_rv,inference)

				parameters.NEW_TRACE = deepcopy(parameters.TRACE)
				parameters.NEW_TRACE["iter"] = iters
				parameters.NEW_TRACE["RC"][chosen_rv]["X"]=new_X	
				parameters.NEW_TRACE["RC"][chosen_rv]["logl"]=new_logl
			else
				#block proposal
				parameters.NEW_TRACE = deepcopy(parameters.TRACE)
				for ii=eachindex(chosen_rv)
					crv = chosen_rv[ii]
					new_X,new_logl, F, R = sample_from_proposal(parameters.TRACE,crv,inference)
					parameters.NEW_TRACE["RC"][crv]["X"]=new_X
					parameters.NEW_TRACE["RC"][crv]["logl"]=new_logl
				end
			end

			parameters.CURRENT_TRACE = deepcopy(parameters.NEW_TRACE)
			# println("AFTER CHOBJ:", parameters.CURRENT_TRACE["RC"]["G1"]["ch_object"])		
			trace_update(parameters.TAST)
			parameters.NEW_TRACE = deepcopy(parameters.CURRENT_TRACE)
			new_ll = parameters.NEW_TRACE["ll"]; ll_fresh = parameters.NEW_TRACE["ll_fresh"]; ll_stale = parameters.NEW_TRACE["ll_stale"]

			#acceptance ratio
			if new_ll == -1e200
				ACC = -1e200
			else
				ACC = new_ll - ll + R - F + log(length(parameters.TRACE["RC"])) - log(length(parameters.NEW_TRACE["RC"])) + ll_stale - ll_fresh
			end

			if mode == "HALLUCINATE"
				ACC = 1e100
			end

			if log(rand()) < ACC #accept
				parameters.TRACE = deepcopy(parameters.NEW_TRACE)
				ll = new_ll
				debug_callback(parameters.TRACE)
			else# Rejected
				parameters.NEW_TRACE = Dict()
			end
		########## HMC ##########
		elseif inference == "HMC"
			parameters.TRACE = hmc_propose(chosen_rv, debug_callback)
		elseif inference == "Gibbs"
			parameters.TRACE = gibbs_propose(chosen_rv, debug_callback)
		elseif inference == "LBFGS"
			parameters.TRACE = lbfgs_propose(chosen_rv, debug_callback, args)
		elseif inference == "SGD"
			parameters.TRACE = SGD(group_name, debug_callback, iterations)
		elseif inference == "ELLIPTICAL"
			parameters.TRACE = ELLIPTICAL(chosen_rv, debug_callback)
		end
	end

end

# end #debug

# end #module Picture



