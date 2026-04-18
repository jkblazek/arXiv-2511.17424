
mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"auctio.jl")

# E[x]=sum(ai*xi)/sum(ai)
# V[x]=sum(ai*(xi-E[x])^2)/sum(ai)=sum(ai*xi^2)/sum(ai)-E[x]^2
# unbiased V[x]=sum(ai*(xi-E[x])^2)/(sum(ai)-sum(ai^2)/sum(ai))
function statmarket(player::Player,market::Market)
	N=length(player.x)
	ptot=0.0; vtot=0.0; atot=0.0; a2tot=0.0; azer=0
	value=0.0; cost=0.0
	for i=2:N
		mai=ai(i,market)
		value+=player.x[i].theta(mai)
		cost+=ci(i,player,market)
		if mai<0.001
			azer+=1
		end
		ptot+=mai*market.p[i]
		vtot+=mai*market.p[i]*market.p[i]
		atot+=mai
		a2tot+=mai*mai
	end
	if atot<=1e-12
		return 0.0,0.0,value,cost,azer
	end
	pavg=ptot/atot; γ=a2tot/atot
	if atot>γ
		pvar=abs((vtot-pavg*pavg*atot)/(atot-γ))
	else
		pvar=0.0
	end
	return pavg,pvar,value,cost,azer
end

# Compute time-weighted averages from a traj file.
# buyers and data come from load_traj.
# Returns (pavg, pvar, avg) where avg is a Dict{Int,Vector{Float64}}:
#   avg[i] = [a_avg, v_avg, c_avg, u_avg] for buyer i.
# pavg/pvar are allocation-weighted over non-reserve buyers present in playeru.
# Pass playeru=nothing to skip pavg/pvar computation.
function traj_timeavg(tvec, Qvec, buyers, data,
		playeru::Union{Player,Nothing}=nothing)
	K,M,_=size(data)
	T=tvec[end]-tvec[1]
	T<=0.0 && return 0.0, 0.0, Dict{Int,Vector{Float64}}()
	sums=zeros(Float64,M,4)
	for k=1:K-1
		dt=tvec[k+1]-tvec[k]
		dt<=0.0 && continue
		for j=1:M
			for f=1:4
				sums[j,f]+=data[k,j,f]*dt
			end
		end
	end
	avg=Dict{Int,Vector{Float64}}()
	for j=1:M
		avg[buyers[j]]=[sums[j,f]/T for f=1:4]
	end
	# pavg/pvar: allocation-weighted, non-reserve buyers only
	pavg=0.0; pvar=0.0
	if playeru !== nothing
		atot=0.0; ptot=0.0; p2tot=0.0
		for j=1:M
			i=buyers[j]
			i==1 && continue  # skip reserve
			i>length(playeru.x) && continue
			a=avg[i][1]
			p=playeru.x[i].dtheta(a)
			atot+=a; ptot+=a*p; p2tot+=a*p^2
		end
		if atot>1e-12
			pavg=ptot/atot
			pvar=max(0.0, p2tot/atot - pavg^2)
		end
	end
	return pavg, pvar, avg
end

