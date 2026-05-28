
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

# Compute time-weighted averages and utility variance from a traj file.
# buyers and data come from load_traj.
# burnin: skip all events before this time (default 0.0 = full trajectory).
#         Pass Qper to drop the first supply oscillation period.
# Returns (avg, var, dev):
#   avg[i] = [a_avg, v_avg, c_avg, u_avg]  time-weighted mean per buyer
#   var[i] = (1/T) int (u_i(t) - avg_u_i)^2 dt
#   dev[i] = sqrt(var[i])
function traj_timeavg(tvec, Qvec, buyers, data,
		burnin::Float64=0.0)
	K,M,_=size(data)
	empty=Dict{Int,Vector{Float64}}(), Dict{Int,Float64}(), Dict{Int,Float64}()
	kstart=burnin>0.0 ? searchsortedfirst(tvec, burnin) : 1
	kstart>=K && return empty
	T=tvec[end]-tvec[kstart]
	T<=0.0 && return empty
	sums  =zeros(Float64,M,4)
	sumsq =zeros(Float64,M)
	for k=kstart:K-1
		dt=tvec[k+1]-tvec[k]
		dt<=0.0 && continue
		for j=1:M
			for f=1:4
				sums[j,f]+=data[k,j,f]*dt
			end
			sumsq[j]+=data[k,j,4]*data[k,j,4]*dt
		end
	end
	avg=Dict{Int,Vector{Float64}}()
	var=Dict{Int,Float64}()
	dev=Dict{Int,Float64}()
	for j=1:M
		i=buyers[j]
		avg[i]=[sums[j,f]/T for f=1:4]
		u_avg=avg[i][4]
		v=max(0.0, sumsq[j]/T - u_avg*u_avg)
		var[i]=v
		dev[i]=sqrt(v)
	end
	return avg, var, dev
end

