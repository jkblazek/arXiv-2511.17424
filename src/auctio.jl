
using Printf

function prplayer(player::Player)
	N=length(player.x)
	@printf("%3s  %12s %12s\n","i","barq","kappa")
	for i=2:N
		@printf("%3d: %12g %12g\n",
			i,player.x[i].theta.barql,player.x[i].theta.kappal)
	end
end


function prmarket(player::Player,market::Market)
	@printf("%3s  %12s %12s %12s %12s %12s\n",	
		"i","q","p","a","u","c");
	at=0.0
	tvalue=0.0
	tutil=0.0
	N=length(market.q)
	for i=1:N
		a=ai(i,market); at+=a
		tvalue+=player.x[i].theta(a)
		myui=ui(i,player,market); tutil+=myui
		myci=ci(i,player,market)
		@printf("%3d: %12g %12g %12g %12g %12g\n",
			i,market.q[i],market.p[i],a,myui,myci)
	end
	@printf("%3s  %12s %12s %12g\n","","","",at)
	println("  total value: ",tvalue)
	println("total utility: ",tutil)
end


function logstate(io::IO,t::Float64,player::Player,market::Market)
	@printf(io,"%g %g",t,market.Q)
	for k in market.traji
		mya=ai(k,market)
		myv=player.x[k].theta(mya)
		myc=ci(k,player,market)
		myu=myv-myc
		@printf(io," %g %g %g %g",mya,myv,myc,myu)
	end
	@printf(io,"\n"); flush(io)
end


# Load a traj file written by queueavg/queueconv.
function load_traj(path::String)
	lines=readlines(path)
	header=lines[1]  # "#t Q a1 v1 c1 u1 a2 ..."
	cols=split(header[2:end])  # strip leading '#'
	# parse buyer indices from column names: "a5" -> 5
	buyers=Int[]
	for col in cols[3:end]  # skip "t" and "Q"
		if startswith(col,"a")
			push!(buyers, parse(Int, col[2:end]))
		end
	end
	M=length(buyers)
	rows=filter(l->length(l)>0 && l[1]!='#', lines)
	K=length(rows)
	tvec=zeros(Float64,K)
	Qvec=zeros(Float64,K)
	data=zeros(Float64,K,M,4)
	for (k,row) in enumerate(rows)
		vals=parse.(Float64,split(row))
		tvec[k]=vals[1]; Qvec[k]=vals[2]
		for j in 1:M
			base=2+(j-1)*4
			data[k,j,1]=vals[base+1]  # a
			data[k,j,2]=vals[base+2]  # v
			data[k,j,3]=vals[base+3]  # c
			data[k,j,4]=vals[base+4]  # u
		end
	end
	return tvec, Qvec, buyers, data
end


# Reserve buyer i=1 is skipped — it is always reconstructed analytically.
function save_playeru(path::String, player::Player)
	open(path,"w") do io
		N=length(player.x)
		@printf(io,"#i barq kappa\n")
		for i=2:N
			@printf(io,"%d %g %g\n",
				i, player.x[i].theta.barql, player.x[i].theta.kappal)
		end
	end
end

# Load buyer population from a .dat file written by save_playeru.
# myP is the reserve price used to reconstruct buyer i=1.
function load_playeru(path::String, myP::Float64, scale::Float64=1.0)::Player
	lines=readlines(path)
	rows=filter(l->length(l)>0 && l[1]!='#', lines)
	N=length(rows)+1   # +1 for reserve buyer
	xr=Array{Buyer}(undef,N+1)
	xr[1]=Buyer(z->z*myP, z->myP, z->NaN, Inf)
	for row in rows
		parts=split(row)
		i=parse(Int,parts[1])
		barq=parse(Float64,parts[2])
		kappa=parse(Float64,parts[3])
		t,dt,dti=mktheta(scale,kappa,barq)
		xr[i]=Buyer(t,dt,dti,Inf)
	end
	return Player(xr)
end

# Save converged Nash state: bid (q,p) and allocation a for all buyers.
# Used by oneauct.jl and freelunch.jl after queueconv.
function save_nash(path::String, e::Int, player::Player, market::Market)
	open(path,"w") do io
		N=length(market.q)
		@printf(io,"#e=%d etime=%g\n", e, market.etime)
		@printf(io,"#i q p a\n")
		for i=1:N
			@printf(io,"%d %g %g %g\n",
				i, market.q[i], market.p[i], ai(i,market))
		end
	end
end

# Append one phase-aligned snapshot to an open file.
# Called at each integer multiple of Qper in queueavg.
function log_phase(io::IO, cycle::Int, t::Float64,
		player::Player, market::Market)
	N=length(market.q)
	for i=1:N
		mya=ai(i,market)
		@printf(io,"%d %g %g %d %g %g %g\n",
			cycle, t, market.Q, i, market.q[i], market.p[i], mya)
	end
	flush(io)
end


