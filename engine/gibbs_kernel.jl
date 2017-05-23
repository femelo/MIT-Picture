

using Debug
using Distributions
using NumericExtensions

@debug function gibbs_propose(names, debug_callback)

	params.CURRENT_TRACE = deepcopy(params.TRACE)

	var_trace = params.CURRENT_TRACE["RC"][names[1]]
	xx = var_trace["X"]
	range = var_trace["theta_c"]
	ERP = var_trace["ERP"]

	if ERP == DiscreteUniform
		sample_points_number = range[2]-range[1]+1
		val_list = range[1]:range[2]
	else
		sample_points_number = 200
		val_list = rand(ERP(range...), sample_points_number)
	end
	logl_list = zeros(sample_points_number)

	for ind in 1:sample_points_number #enumerate
		params.CURRENT_TRACE["RC"][names[1]]["X"] = val_list[ind]
		trace_update(params.TAST)
		cur_log_like = params.CURRENT_TRACE["ll"]
		logl_list[ind] = cur_log_like;
	end

	#sample from multinomial and choose
	logl_list = logl_list - logsumexp(logl_list)
	logl_list = exp(logl_list)
	pvector = rand(Multinomial(1,logl_list),1)
	chosen_idx = findin(pvector,1)[1]

	#update trace with chosen value
    params.CURRENT_TRACE["RC"][names[1]]["X"] = val_list[chosen_idx]
	trace_update(params.TAST)
	params.TRACE = deepcopy(params.CURRENT_TRACE)
	debug_callback(params.CURRENT_TRACE)
	return params.CURRENT_TRACE
end
