
using Debugger

function buildInsideLoopList(expressions)
	ind=false
	for i=eachindex(expressions)
		sexpr = string(expressions[i])
		#println(sexpr)
		if ind == true && isLoopBegin(sexpr) == false && isLine(sexpr) == true
			parameters.LOOP_LIST[sexpr] = 1
		end
		if isLoopBegin(sexpr) == true
			ind = true
		end
		if i>2 && isLoopExit(string(expressions[i-1]), string(expressions[i-2])) == true
			ind = false
		end
	end

	return parameters.LOOP_LIST
end

function isLoopBegin(strexpr)
	return occursin(":(unless top", strexpr)
	# if search(strexpr,":(unless top") != 0:-1
	# 	return true
	# else
	# 	return false
	# end
end

function isLoopExit(prev_strexpr, prev_prev_strexpr)
	if occursin("goto", prev_strexpr) && isLoopBegin(prev_strexpr) == false && occursin("top(convert)", prev_prev_strexpr)
		return true
	else
		return false
	end
	# if search(prev_strexpr,"goto") != 0:-1 && isLoopBegin(prev_strexpr) == false && search(prev_prev_strexpr,"top(convert)") != 0:-1
	# 	return true
	# else
	# 	return false
	# end
end

function isInsideLoop(strexpr)
	return haskey(parameters.LOOP_LIST, strexpr)
end

function isLine(strexpr)
	#if search(strexpr,"# line") != 0:-1 && isInsideLoop(strexpr) == false
	if occursin("# line", strexpr) && isInsideLoop(strexpr) == false
		return true
	else
		return false
	end
end

function transform_code(AST)

	# expressions = deepcopy(AST[1].args[3].args)
	expressions = AST[1].code

	# println("========== Original Code =========")
	# for i=eachindex(expressions)
	# 	println(expressions[i])
	# end

	TMP = []
	for i=1:2
		push!(TMP, expressions[i])
	end
	#push!(TMP,:(push!(LINE,0)))

	#all expressions that lie inside for loops
	parameters.LOOP_LIST = buildInsideLoopList(expressions)

	for i=3:length(expressions)
		loopExit = false
		str_exp = string(expressions[i])
		isRC = check_if_random_choice(expressions[i])
		# println(string(isRC),"_", expressions[i])
		if isLoopBegin(str_exp) == true
			tmp_store = pop!(TMP)#we want to append before the goto address
			push!(TMP, :(push!(LOOP,0)))
			push!(TMP, tmp_store)
		elseif isLoopExit(string(expressions[i-1]), string(expressions[i-2])) == true
			loopExit = true
		elseif isInsideLoop(str_exp) == true
			push!(TMP, :(var = pop!(LOOP)+1))
			push!(TMP, :(push!(LOOP,var)))
		elseif isLine(str_exp) == true
			push!(TMP, :(var = pop!(LINE)+1))
			push!(TMP, :(push!(LINE,var)))
		end

		if isRC == true
			#if search(str_exp,"memoize") != 0:-1 || search(str_exp,"block") != 0:-1
			if occursin("memoize", str_exp) || occursin("block", str_exp)
				#memoize or block
				tmp_exp = deepcopy(expressions[i])
				print(tmp_exp.args[2]) # ERROR HERE
				mem_or_block_var = tmp_exp.args[2].args[2]
				rv_exp = tmp_exp.args[2].args[3]
				tmp_exp = deepcopy(expressions[i])
				#tmp_exp.args[2] = rv_exp
				push!(tmp_exp.args[2].args, :LINE)
				push!(tmp_exp.args[2].args, :FUNC)
				push!(tmp_exp.args[2].args, :LOOP)
				push!(tmp_exp.args[2].args, :MEM)
				push!(tmp_exp.args[2].args, :BID)
				tmp_str = string(tmp_exp.args[2].args[1])
				tmp_str = string(tmp_str, "_DB")
				tmp_exp.args[2].args[1] = Symbol(tmp_str)
				mem_expr = :(MEM=NaN)
				block_expr = :(BID="")
				if occursin("memoize", str_exp)
					mem_expr.args[2]=mem_or_block_var
				elseif occursin("block", str_exp)
					block_expr.args[2]=mem_or_block_var
				end
				push!(TMP,mem_expr)
				push!(TMP,block_expr)
				push!(TMP,tmp_exp)
	
			else
				tmp_exp = deepcopy(expressions[i])
				#push!(tmp_exp.args[2].args,:CURRENT_TRACE)
				push!(tmp_exp.args[2].args, :LINE)
				push!(tmp_exp.args[2].args, :FUNC)
				push!(tmp_exp.args[2].args, :LOOP)
				push!(tmp_exp.args[2].args, :MEM)
				push!(tmp_exp.args[2].args, :BID)
				tmp_str = string(tmp_exp.args[2].args[1])
				tmp_str = string(tmp_str, "_DB")
				tmp_exp.args[2].args[1] = symbol(tmp_str)
				push!(TMP,:(MEM=NaN))
				push!(TMP,:(BID=""))
				push!(TMP,tmp_exp)
			end
		else
			push!(TMP,expressions[i])
			#we need to add this after loop closing for correctness
			if loopExit == true
				push!(TMP,:(pop!(LOOP)))
			end
		end
	end
	println("========== Transformed Code =========")
	for i=eachindex(TMP)
		println(TMP[i])
	end
	
	TAST = copy(AST)
	#TAST[1].args[3].args=TMP
	TAST[1].code = TMP
	return TAST
end
