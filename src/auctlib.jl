# This auction implements the Algorithm 1 from Appendix B in
# Lazar, Semret, Design and Analysis of the Progressive Second
# Price Auction for Bandwidth Sharing

# It does not always converge to a Nash-epsilon equilibrium
# because the value returned by SupGi is so large that it is
# of zero marginal value to the player.  As a result, the
# price given by dtheta is zero and no allocation occurs.

# Better with average tie splitting allocations # based on 
# Qu, Jia and Caines, Analysis of a Class of Decentralized 
# Decision Processes: Progressive Second Price Auctions.

# The cost functions are weird as they factor in somewhat
# arbitrary benefit to poor players who would temporary
# benefit from a player i dropping out until the a new
# equilibrium is established.  This does not appear to
# affect algorithm 1 as all involved players continue to
# increase their utility functions relative to temporary
# benefits to the others.

# What's not clear is how this will effect two coupled
# markets: one poor and the other rich.  As the utility 
# for rich entering a poor market might reflect current
# pricing when they entered.

using Printf, Random

function mktheta(scale::Float64=1.0,
		kappa::Float64=0.0,barq::Float64=0.0)
	if barq==0.0
		barq=scale*rand()*50+50
	end	
	if kappa==0.0
		kappa=scale*(rand()*10+10)/barq
	end
	theta=let
		barql=barq
		kappal=kappa
		function theta(z::Float64)
			zmin=min(z,barql)
			return (-kappal*zmin/2+kappal*barql)*zmin
		end
	end
	dtheta=let
		barql=barq
		kappal=kappa
		function dtheta(z::Float64)
			r=kappal*(barql-z)
			if r<0.0
				return 0.0
			end
			return r
		end
	end
	# r=-kz+kq; kz=kq-r; z=q-r/k
	# r=k(q-z); q-z=r/k; z=q-z/k
	dthetainv=let
		barql=barq
		kappal=kappa
		function dthetainv(r::Float64)
			z=barql-r/kappal
			if z<0.0
				return 0.0
			end
			return z
		end
	end
	return theta,dtheta,dthetainv
end

@isdefined(gN) || const gN=10
@isdefined(gM) || const gM=0

const EV_THINK=1
const EV_BID=2
const EV_SUPPLY=3

mutable struct Node
	t::Float64   # event time
	t0::Float64  # time sent / last update
	i::Int       # buyer index for buyer events, 0 for supply
	q::Float64   # quantity
	p::Float64   # marginal value
	kind::Int    # EV_THINK, EV_BID, or EV_SUPPLY
end
mutable struct Buyer
	theta::Function
	dtheta::Function
	dthetainv::Function
	t0::Float64
	q::Float64
	p::Float64
	function Buyer(scale::Float64=1.0)
		thetar,dthetar,dthetainvr=mktheta(scale)
		return new(thetar,dthetar,dthetainvr,0.0,0.0,0.0)
	end
	function Buyer(thetap::Function,dthetap::Function,
		dthetainvp::Function,Bp::Float64)
		return new(thetap,dthetap,dthetainvp,0.0,0.0,0.0)
	end
end
mutable struct Player
	x::Array{Buyer}
	function Player(scale::Float64=1.0,N::Int=gN)
		xr=Array{Buyer}(undef,N)
		xr[1]=Buyer(z->0.0,z->0.0,z->Nan,Inf)
		for i=2:N
			xr[i]=Buyer(scale)
		end
		return new(xr)
	end
	function Player(xr::Array{Buyer})
		return new(xr)
	end
end

mutable struct Market
	p::Array{Float64}   # current price
	q::Array{Float64}   # current quantity
	t0::Array{Float64}  # time the current bid was sent
	Q::Float64          # current total supply (may be time-varying)
	Qbase::Float64      # baseline supply level for oscillatory experiments
	Qamp::Float64       # oscillation amplitude as a fraction of Qbase (0 disables)
	Qper::Float64       # oscillation period in simulation time units (0 disables)
	Qphase::Float64     # phase shift (radians)
	Qmin::Float64       # absolute minimum supply clamp
	Qdt::Float64        # supply sampling interval (<=0 disables supply events)
	Tend::Float64       # time horizon for non-convergent runs (<=0 uses convergence stop)
	epsilon::Float64
	twins::Float64      # are we twinning
	mcount::Int         # market evaluations
	bcount::Int         # count of bids
	etime::Float64      # total time of auction
	bdelay::Float64
	blambda::Float64
	bshape::Float64
	cdelay::Float64
	clambda::Float64
	cshape::Float64
	traji::Array{Int}

    Market(N::Int=gN) = new(
        zeros(N), zeros(N), zeros(N),
        100.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0,
        5.0, 0.0, 0, 0, 0.0,
        1.0, 0.25, 1.5, 0.1, 1.0, 0.75,
        zeros(Int,0)
    )
end



# Time-varying supply (oscillatory) support.
# If Qamp==0 or Qper==0, supply stays fixed at Q.
function supplyQ(t::Float64, market::Market)
	if market.Qamp == 0.0 || market.Qper == 0.0
		return market.Q
	end
	# Q(t) = max(Qmin, Qbase * (1 + Qamp * sin(2π t / Qper + Qphase)))
	qt = market.Qbase * (1.0 
			+ market.Qamp * sin(2*pi*t/market.Qper + market.Qphase))
	return max(qt, market.Qmin)
end

function update_supply!(player::Player, market::Market, t::Float64)
	market.Q = supplyQ(t, market)
	# Reserve buyer (i=1) always posts the full supply at its reserve price.
	market.q[1] = market.Q
	market.p[1] = player.x[1].dtheta(market.Q)
	return nothing
end


function Qi(i::Int,y::Float64,market::Market)
	r=market.Q
	N=length(market.q)
	for k=1:N
		if k!=i && market.p[k]>y
			r-=market.q[k]
		end
	end
	return max(r,0.0)
end

function barQi(i::Int,y::Float64,market::Market)
	r=market.Q
	N=length(market.q)
	for k=1:N
		if k!=i && market.p[k]>=y
			r-=market.q[k]
		end
	end
	return max(r,0.0)
end

function tieQi(i::Int,y::Float64,market::Market)
	N=length(market.q)
	r=market.Q; d=market.q[i]
	dc=1.0
	for k=1:N
		if k!=i
			if market.p[k]>y
				r-=market.q[k]
			elseif market.p[k]==y
				d+=market.q[k]; dc+=1.0
			end
		end
	end
	if d==0
		return max(r,0.0)/dc
	end
	return market.q[i]*max(r,0.0)/d
end

function Pi(i::Int,z::Float64,market::Market)
	if z>market.Q
		println("in Pi z=$z was greater than Q=",market.Q)
	end
	N=length(market.q)
	ks=[1:i-1; i+1:N]
	ksort=sort(ks,lt=(x,y)->market.p[x]>market.p[y])
	qtot=0.0
	for k in ksort
		qtot+=market.q[k]
		if market.Q-qtot<z
			return market.p[k]
		end
	end
	return 0.0
end

function intPi(i::Int,a::Float64,market::Market)
	r=0.0
	if a<=0
		return r
	end
	N=length(market.q)
	ks=[1:i-1; i+1:N] 
	ksort=sort(ks,lt=(x,y)->market.p[x]>market.p[y])
	xi=market.Q
	for k in ksort
		xi-=market.q[k]
		if xi<0
			xi=0
		end
		if xi<a
			r+=market.p[k]*(a-xi)
			a=xi
		end
	end
	return r
end

function supGi(i::Int,player::Player,market::Market)
	N=length(market.q)
	ks=[1:i-1; i+1:N]
	ksort=sort(ks,lt=(x,y)->market.p[x]>market.p[y])
	z=market.Q
	zsup=z
	for k in ksort
		if player.x[i].dtheta(z)>=market.p[k]
			return max(z,zsup)
		end
		zsup=player.x[i].dthetainv(market.p[k])
		z-=market.q[k]
		if z<0
			break
		end
	end
	return zsup
end

function ai(i::Int,market::Market)
	r=tieQi(i,market.p[i],market)
	return min(market.q[i],r)
end

function ci(i::Int,player::Player,market::Market)
	r=0.0
	marketmi=deepcopy(market)
	marketmi.q[i]=0; marketmi.p[i]=0
	N=length(market.q)
	for j=1:N
		if j!=i
			aimi=ai(j,marketmi)
			aiwi=ai(j,market)
			r+=market.p[j]*(aimi-aiwi)
		end
	end
	return r
end

function ui(i::Int,player::Player,market::Market)
	a=ai(i,market)
	return player.x[i].theta(a)-ci(i,player,market)
end

function bidi(i::Int,player::Player,market::Market)
	market.mcount+=1
	uiold=ui(i,player,market)
	viold=market.q[i]; wiold=market.p[i]
	zi=min(supGi(i,player,market),player.x[i].theta.barql)
	vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
	winew=player.x[i].dtheta(vinew)
	market.q[i]=vinew; market.p[i]=winew
	uinew=ui(i,player,market)
	if uinew<=uiold+market.epsilon
		market.q[i]=viold; market.p[i]=player.x[i].dtheta(market.q[i])
		return 0
	else
		market.bcount+=1
		return 1
	end
end

function guba(i::Int,player::Player,market::Market)
	aiold=ai(i,market)
	viold=market.q[i]
	c=(aiold+viold)/2
	if c!=viold
		market.q[i]=c; market.p[i]=player.x[i].dtheta(c)
		return 1
	end
	return 0
end

function doround(player::Player,market::Market)
	c=0
	N=length(market.q)
	for i=2:N
		c+=bidi(i,player,market)
	end
	return c
end

function gubaround(player::Player,market::Market)
	c=0
	N=length(market.q)
	for i=2:N
		c+=guba(i,player,market)
	end
	return c
end

using Printf

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

function prplayer(player::Player)
	N=length(player.x)
	@printf("%3s  %12s %12s\n","i","barq","kappa")
	for i=2:N
		@printf("%3d: %12g %12g\n",
			i,player.x[i].theta.barql,player.x[i].theta.kappal)
	end
end

function doconv(player::Player,market::Market)
	market.bcount=0; market.mcount=0
	for l=1:10000
		if doround(player,market)==0
			return l
		end
	end
	println("Didn't converge")
	return 0
end

function gubaconv(player::Player,market::Market)
	for l=1:10000
		if gubaround(player,market)==0
			println("Converged in $l rounds")
			prmarket(player,market)
			return l
		end
	end
	println("Didn't converge")
	return 0
end

#= Fido's very own priority queue in Julia =#
function mkpriority()::Tuple{Function,Function}
	heap=Node[]
	function enqueue(p::Node)
		push!(heap,p)
		r=length(heap)
		while true
			s=r÷2
			if s<1 break end
			if heap[s].t<=p.t break end
			heap[r]=heap[s]
			r=s
		end
		heap[r]=p
	end
	function dequeue()::Node
		if length(heap)==0
			println("Tried to remove nonexistent point!\n")
			throw(DoExit())
		end
		u=pop!(heap)
		if length(heap)==0 return u end
		p=heap[1]
		s0=1
		while true
			r0=2*s0; r1=r0+1
			if r0>length(heap) break end
			s1=r0
			if r1<=length(heap)
				if heap[r0].t>heap[r1].t
					s1=r1
				end
			end
			if u.t<=heap[s1].t break end
			heap[s0]=heap[s1]
			s0=s1
		end
		heap[s0]=u
		return p
	end
	return enqueue,dequeue
end

# PDF αβx^(β-1)exp(-αx^β) where λ=(1/α)^(1/β) or α=(1/λ)^β
# In terms of λ we have β(1/λ)^βx^(β-1)exp(-(x/λ)^β)
# The mean μ=(1/α)^(1/β)Γ(1+1/β)=λΓ(1+1/β) and the variance is
# σ^2=(1/α)^(2/β)[Γ(1+2/β)-Γ^2(1+1/β)]=λ^2[Γ(1+2/β)-Γ^2(1+1/β)]
function rweibull(lambda,beta::Float64)::Float64
	return lambda*(-log(1-rand()))^(1/beta)
end

function getbidi(i::Int,player::Player,market::Market)
	market.mcount+=1
	viold=market.q[i]; wiold=market.p[i]
	if player.x[i].t0>0  # updated bid even if not received
		market.q[i]=player.x[i].q; market.p[i]=player.x[i].p
	end
	uiold=ui(i,player,market)
	zi=min(supGi(i,player,market),player.x[i].theta.barql)
	vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
	winew=player.x[i].dtheta(vinew)
	market.q[i]=vinew; market.p[i]=winew
	uinew=ui(i,player,market)
	market.q[i]=viold; market.p[i]=wiold
	if uinew<=uiold+market.epsilon
		return 0.0,0.0       # Don't want to make a bid
	else
		return vinew,winew
	end
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

function sendbid(v::Node,player::Player,market::Market)
    i=v.i
	N=length(player.x); T2=N÷2+1
	q,p=getbidi(i,player,market)
	if q>0 
		market.bcount+=1
		player.x[i].t0=v.t0  # remember the bid we sent
		player.x[i].q=q
		player.x[i].p=p
		dt=market.cdelay+rweibull(market.clambda,market.cshape)
		if market.twins>0.0&&i>T2
			dt*=market.twins
		end
		ct=v.t0+dt
        #enc(Node(ct,v.t0,i,q,p,EV_BID))
		#return Node(ct,v.t0,i,q,p,EV_BID) #t0 is the snapshot time
        player.x[i].t0=v.t
        return Node(ct,v.t,i,q,p,EV_BID) #t is the bid time
	end
	return nothing
end

function receivebid(v::Node,player::Player,market::Market)
    i=v.i
	if market.t0[i]<=v.t0
		market.t0[i]=v.t0      # bid at t0 is now active
		market.q[i]=v.q; market.p[i]=v.p
	end
end

function queueconv(player::Player,market::Market,e::Int)
	trajfp::Union{IO,Nothing}=nothing
	if length(market.traji)>0
		mkpath("time")
		trajfp=open(@sprintf("time/traj%03d.dat",e),"w")
		@printf(trajfp,"#t Q")
		for k in market.traji
			@printf(trajfp," a%d v%d c%d u%d",k,k,k,k)
		end
		@printf(trajfp,"\n"); flush(trajfp)
	end
	enc,deq=mkpriority()
	N=length(player.x); T2=N÷2+1
	d=market.blambda
	market.bcount=0; market.mcount=0
	bidflying=0
	if d>0
		for i=2:N
			t=market.bdelay+rweibull(d,market.bshape)
			if market.twins>0&&i>T2
				t*=market.twins
			end
			enc(Node(t,0.0,i,0.0,0.0,EV_THINK))
		end
	else
		for i=2:N
			weibull(d,market.bshape)
			t=market.bdelay*(1.0+(i-1)/N)
			if market.twins>0&&i>T2
				t*=market.twins
			end
			enc(Node(t,0.0,i,0.0,0.0,EV_THINK))
		end
	end
	reply=ones(Int,N); reply[1]=0
	while length(enc.heap)>0
		v=deq()
		if v.kind==EV_THINK
			v.t0=v.t
            w=sendbid(v,player,market)
            if w!==nothing
                enc(w)
			    bidflying+=1
            end
			if bidflying==0
				reply[v.i]=0
			end
			dt=market.bdelay+rweibull(market.blambda,market.bshape)
			if market.twins>0.0&&v.i>T2
				dt*=market.twins
			end
			v.t=v.t0+dt
			enc(v)
		else
			bidflying-=1
			receivebid(v,player,market)
            if length(market.traji)>0
                @printf(trajfp,"%g",v.t)
                for k in market.traji
                    myvk=player.x[k].theta(ai(k,market))
                    myck=ci(k,player,market)
                    @printf(trajfp," %g %g",myvk,myck)
                end
                @printf(trajfp,"\n"); flush(trajfp)
            end
            v.t0=v.t
			for i=2:N
				reply[i]=1
			end
		end
		if bidflying==0 && sum(reply)==0
			market.etime=v.t0
			break
		end
	end
	if length(market.traji)>0
		close(trajfp)
	end
	return 0
end

#
# TODO #2:
# Also create a new queue item corresponding to when the quantity
# of resource changes in the auction, and write out the state of
# the allocations and second prices each time either the resource
# in the auction changes or a bid changes.  Every time a change
# in the available is dequeued, then process it and requeue the
# next scheduled change in resource.  All the the same queue.
#
function queueavg(player::Player,market::Market,e::Int,
		phasefp::Union{IO,Nothing}=nothing)
	trajfp::Union{IO,Nothing}=nothing
	if length(market.traji)>0
		mkpath("time")
		trajfp=open(@sprintf("time/traj%03d.dat",e),"w")
		@printf(trajfp,"#t Q")
		for k in market.traji
			@printf(trajfp," a%d v%d c%d u%d",k,k,k,k)
		end
		@printf(trajfp,"\n"); flush(trajfp)
	end
	enc,deq=mkpriority()
	N=length(player.x); T2=N÷2+1
	d=market.blambda
	market.bcount=0; market.mcount=0
	if d>0
		for i=2:N
			t=market.bdelay+rweibull(d,market.bshape)
			if market.twins>0&&i>T2
				t*=market.twins
			end
			enc(Node(t,0.0,i,0.0,0.0,EV_THINK))
        end
	else
		for i=2:N
			weibull(d,market.bshape)
			t=market.bdelay*(1.0+(i-1)/N)
			if market.twins>0&&i>T2
				t*=market.twins
            end
			enc(Node(t,0.0,i,0.0,0.0,EV_THINK))
        end
	end
	if market.Qdt>0.0
		update_supply!(player,market,0.0)
		enc(Node(market.Qdt,0.0,0,0.0,0.0,EV_SUPPLY))
		if trajfp !== nothing
			logstate(trajfp,0.0,player,market)
		end
	end
	phase_cycle=0   # counts completed supply oscillation cycles
	while length(enc.heap)>0
		v=deq()
		if v.t>market.Tend
			market.etime=v.t
			break
		end
		if v.kind==EV_SUPPLY
			update_supply!(player,market,v.t)
			if trajfp !== nothing
				logstate(trajfp,v.t,player,market)
			end
			# phase snapshot: record at each integer multiple of Qper
			if phasefp !== nothing && market.Qper > 0.0
				new_cycle=floor(Int, v.t / market.Qper)
				if new_cycle > phase_cycle
					phase_cycle=new_cycle
					log_phase(phasefp, phase_cycle, v.t, player, market)
				end
			end
			enc(Node(v.t+market.Qdt,v.t,0,0.0,0.0,EV_SUPPLY))
		elseif v.kind==EV_THINK
			v.t0=v.t
			w=sendbid(v,player,market)
            if w!==nothing
                enc(w)
            end
			dt=market.bdelay+rweibull(market.blambda,market.bshape)
			if market.twins>0.0&&v.i>T2
				dt*=market.twins
			end
			v.t=v.t0+dt
			enc(v)
		else
			receivebid(v,player,market)
	    	if trajfp != nothing
				logstate(trajfp,v.t,player,market)
            end
		end
	end
	if trajfp !== nothing
		close(trajfp)
	end
	return 0
end

# Save buyer population parameters (barq, kappa per buyer).
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

function randbids(player::Player,market::Market)
	N=length(market.q)
	for i=2:N
		market.q[i]=rand()*player.x[i].theta.barql
		market.p[i]=player.x[i].dtheta(market.q[i])
	end
end

function halfbids(player::Player,market::Market)
	N=length(market.q)
	for i=2:N
		market.q[i]=0.5*player.x[i].theta.barql
		market.p[i]=player.x[i].dtheta(market.q[i])
	end
end

function single(playeru::Player,mQ::Float64=100.0,rbids::Int=0)
	player=deepcopy(playeru)
	myN=length(playeru.x)
	market=Market(myN)
	market.Q=mQ
	market.Qbase=mQ
	if rbids>0
		randbids(player,market)
	else
		halfbids(player,market)
	end
	market.q[1]=mQ; market.p[1]=player.x[1].dtheta(mQ)
	return player,market
end
