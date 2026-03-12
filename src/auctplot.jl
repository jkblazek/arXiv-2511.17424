# Some plotting routines moved here

using Printf, Plots, Random

#plot()
#for gi=1:10
#display(plot!(ucurve(gi,player,market),label=""))
#display(scatter!([ai(gi,player,market)],[ui(gi,player,market)],
#label="$gi"))
#end
function ucurve(i::Int,player::Player,market::Market)
	marketmi=deepcopy(market)
	qs=[0:0.1:100.0;]
	zs=zeros(length(qs))
	for k=1:length(qs)
		marketmi.q[i]=qs[k]
		marketmi.p[i]=player.x[i].dtheta(marketmi.q[i])
		zs[k]=ui(i,player,marketmi)
	end
	return qs,zs
end

function ccurve(i::Int,player::Player,market::Market)
	marketmi=deepcopy(market)
	qs=[0:0.1:100.0;]
	zs=zeros(length(qs))
	for k=1:length(qs)
		marketmi.q[i]=qs[k]
		marketmi.p[i]=player.x[i].dtheta(marketmi.q[i])
		zs[k]=ci(i,player,marketmi)
	end
	return qs,zs
end

function acurve(i::Int,player::Player,market::Market)
	marketmi=deepcopy(market)
	qs=[0:0.1:100.0;]
	zs=zeros(length(qs))
	for k=1:length(qs)
		marketmi.q[i]=qs[k]
		marketmi.p[i]=player.x[i].dtheta(marketmi.q[i])
		zs[k]=ai(i,marketmi)
	end
	return qs,zs
end

function qcurve(i::Int,player::Player,market::Market)
	marketmi=deepcopy(market)
	qs=[0:0.1:100.0;]
	zs=zeros(length(qs))
	for k=1:length(qs)
		marketmi.q[i]=qs[k]
		marketmi.p[i]=player.x[i].dtheta(marketmi.q[i])
		zs[k]=tieQi(i,marketmi.p[i],marketmi)
	end
	return qs,zs
end

# for d in 1:360; display(plot(ps,qs,zs,st=:surface,camera=(d,30))); end
function uplane(i::Int,player::Player,market::Market)
	marketmi=deepcopy(market)
	qs=[0:0.1:100.0;]
	ps=[0:0.1:15;]
	zs=zeros(length(ps),length(qs))
	for k=1:length(qs)
		for j=1:length(ps)
			marketmi.q[i]=qs[k]
			marketmi.p[i]=ps[j]
			zs[j,k]=ui(i,player,marketmi)
		end
	end
	return qs,ps,zs
end
