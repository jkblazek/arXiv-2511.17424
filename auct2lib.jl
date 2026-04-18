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

using Printf, Serialization, Random

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

mutable struct Buyer
	theta::Function
	dtheta::Function
	dthetainv::Function
	B::Float64
	function Buyer(scale::Float64=1.0)
		thetar,dthetar,dthetainvr=mktheta(scale)
		return new(thetar,dthetar,dthetainvr,10.0)
	end
	function Buyer(thetap::Function,dthetap::Function,
		dthetainvp::Function,Bp::Float64)
		return new(thetap,dthetap,dthetainvp,10.0)
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
end

mutable struct Market
	p::Array{Float64}
	q::Array{Float64}
	Q::Float64
	epsilon::Float64
	bdelay::Float64
	blambda::Float64
	bshape::Float64
	cdelay::Float64
	clambda::Float64
	cshape::Float64
	Market(N::Int=gN)=new(zeros(N),zeros(N),100.0,5.0,
		1.0,0.25,1.5, 0.1,1.0,0.75)
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

function tieQislow(i::Int,y::Float64,market::Market)
	N=length(market.q)
	r=Qi(i,y,market); d=market.q[i]
	for k=1:N
		if k!=i && market.p[k]==y
			d+=market.q[k]
		end
	end
	if d==0
		return 0.0
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
#			@printf("+ %g*%g=%g\n",market.p[k],a-xi,
#				market.p[k]*(a-xi))
			r+=market.p[k]*(a-xi)
			a=xi
		end
	end
	return r
end

function supGislow(i::Int,player::Player,market::Market)
	N=length(market.q)
	za=0.0; zb=min(market.Q,player.x[i].theta.barql); zcold=za
	for l=1:100
		zc=(za+zb)/2
		if zc==zcold
			break
		end
		zcold=zc
		if zc<=Qi(i,player.x[i].dtheta(zc),market)
#		if zc<=tieQi(i,player.x[i].dtheta(zc),market)
			za=zc
		else
			zb=zc
		end
	end
	return za
end

function supGi(i::Int,player::Player,market::Market)
	N=length(market.q)
	ks=[1:i-1; i+1:N]
	ksort=sort(ks,lt=(x,y)->market.p[x]>market.p[y])
	z=market.Q
	zsup=z
#	@printf("%12s %12s %12s %12s\n","z",
#		"dθ(z)","p[k]","dθinv(p)")
	for k in ksort
#		@printf("%12g %12g %12g %12g\n",z,
#			player.x[i].dtheta(z),market.p[k],
#			player.x[i].dthetainv(market.p[k]))
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

#  The previous routine with budget constraint -- not implemented
function supGibud(i::Int,player::Player,market::Market)
	N=length(market.q)
	ks=[1:i-1; i+1:N]
	ksort=sort(ks,lt=(x,y)->market.p[x]>market.p[y])
	z=market.Q
	zsup=z
#	@printf("%12s %12s %12s %12s\n","z",
#		"dθ(z)","p[k]","dθinv(p)")
	for k in ksort
#		@printf("%12g %12g %12g %12g\n",z,
#			player.x[i].dtheta(z),market.p[k],
#			player.x[i].dthetainv(market.p[k]))
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

# Only player i is used but not the others
function supGi2slow(i::Int,player::Player,
		market1::Market,market2::Market)
	za=0.0; zb=market1.Q+market2.Q; zcold=za
	for l=1:100
		zc=(za+zb)/2
		if zc==zcold
			break
		end
		zcold=zc
		if zc<=Qi(i,player.x[i].dtheta(zc),market1)+Qi(
				i,player.x[i].dtheta(zc),market2)
			za=zc
		else
			zb=zc
		end
	end
	return za
end

function supGi2(i::Int,player::Player,
		market1::Market,market2::Market)
	N1=length(market1.q); N2=length(market2.q)
	ks=[1:i-1; i+1:N1; N1+1:N1+i-1; N1+i+1:N1+N2]
	function getp(x::Int)
		if x>N1
			return market2.p[x-N1]
		else
			return market1.p[x]
		end
	end
	function getq(x::Int)
		if x>N1
			return market2.q[x-N1]
		else
			return market1.q[x]
		end
	end
	ksort=sort(ks,lt=(x,y)->getp(x)>getp(y))
	z1=market1.Q; z2=market2.Q
	zsup=z1+z2
#	@printf("%4s %10s+%-10s %12s %12s %12s\n","k","z1","z2",
#		"dθ(z)","p[k]","dθinv(p)")
	for k in ksort
#		@printf("%4d %10g+%-10g %12g %12g %12g\n",k,z1,z2,
#			player.x[i].dtheta(z1+z2),getp(k),
#			player.x[i].dthetainv(getp(k))),
		if player.x[i].dtheta(z1+z2)>=getp(k)
			return max(z1+z2,zsup)
		end
		zsup=player.x[i].dthetainv(getp(k))
		if k>N1
			z2=max(0.0,z2-getq(k))
		else
			z1=max(0,0,z1-getq(k))
		end
		if z1+z2<=0.0
			break
		end
	end
	return zsup
end

function ai(i::Int,market::Market)
	r=tieQi(i,market.p[i],market)
#	r=barQi(i,market.p[i],market)
	return min(market.q[i],r)
end

function aislow(i::Int,market::Market)
	N=length(market.q)
	r=Qi(i,market.p[i],market)
	d=0.0
	for k=1:N
		if market.p[k]==market.p[i]
			d+=market.q[k]
		end
	end
	if d==0
		return 0.0
	end
	return market.q[i]*min(r/d,1.0)
end

function cidebug(i::Int,player::Player,market::Market)
	r=0.0
	marketmi=deepcopy(market)
	marketmi.q[i]=0; marketmi.p[i]=0
	N=length(market.q)
	for j=1:N
		if j!=i
			aimi=ai(j,marketmi)
			aiwi=ai(j,market)
			@printf("%12g %12g\n",aimi,aiwi)
			r+=market.p[j]*(aimi-aiwi)
		end
	end
	return r
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

# This function assumes that player[i]==player2[i] but
# the other players can be different
function ui2(i::Int,player::Player,player2::Player,
		market::Market,market2::Market)
	a=ai(i,market)+ai(i,market2)
	r=player.x[i].theta(a)-ci(i,player,market)-ci(i,player2,market2)
	return r
end

function setfairi(player::Player,market::Market,i::Int)
	N=length(market.q)
	market.q[i]=market.Q/(N-1)
	if market.q[i]>player.x[i].theta.barql
		market.q[i]=player.x[i].theta.barql/2
	end
	market.p[i]=player.x[i].dtheta(market.q[i])
end

function setfairi2(p1::Player,p2::Player,m1::Market,m2::Market,i::Int)
	N=length(m1.q)
	if p1.x[i].theta==p2.x[i].theta
		m1.q[i]=m1.Q/(N-1); m2.q[i]=m2.Q/(N-1)
		if m1.q[i]+m2.q[i]>p1.x[i].theta.barql
			m1.q[i]=p1.x[i].theta.barql*m1.Q/(m1.Q+m2.Q)/2
			m2.q[i]=p1.x[i].theta.barql*m2.Q/(m1.Q+m2.Q)/2
		end
		# Prices should be same in both markets
		m1.p[i]=p1.x[i].dtheta(m1.q[i]+m2.q[i])
		m2.p[i]=p1.x[i].dtheta(m1.q[i]+m2.q[i])
	else
		setfairi(p1,m1,i)
		setfairi(p2,m2,i)
	end
end

function trybidi(i::Int,player::Player,market::Market)
	uiold=ui(i,player,market)
	viold=market.q[i]; wiold=market.p[i]
	zi=min(supGi(i,player,market),player.x[i].theta.barql)
	vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
	winew=player.x[i].dtheta(vinew)
	market.q[i]=vinew; market.p[i]=winew
	uinew=ui(i,player,market)
	@printf("(%g,%g) %g -> (%g,%g) %g ",
		viold,wiold,uiold,vinew,winew,uinew)
	market.q[i]=viold; market.p[i]=wiold
	if uinew>uiold+market.epsilon
		@printf("->\n")
	else
		@printf("\n")
	end
end

function bidi(i::Int,player::Player,market::Market)
	uiold=ui(i,player,market)
	viold=market.q[i]; wiold=market.p[i]
	zi=min(supGi(i,player,market),player.x[i].theta.barql)
	vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
	winew=player.x[i].dtheta(vinew)
	market.q[i]=vinew; market.p[i]=winew
	uinew=ui(i,player,market)
#	@printf("(%g,%g) %g -> (%g,%g) %g ",
#		viold,wiold,uiold,vinew,winew,uinew)
	if uinew<=uiold+market.epsilon
		if uiold==0
# These policies affect second prices when a player is too generous
# Return to price for our fair share of the total 
#			setfairi(player,market,i)
# Drop out and let reserve pricing manage the second price
#			market.q[i]=0.0; market.p[i]=0
# Don't update the bid is the original algorithm
			market.q[i]=viold; market.p[i]=player.x[i].dtheta(market.q[i])
		else
			market.q[i]=viold; market.p[i]=wiold
		end
#		@printf("\n")
		return 0
	else
#		@printf("->\n")
		return 1
	end
end

function guba_epsilon(i::Int,player::Player,market::Market) 
    uiold=ui(i,player,market)
    viold=market.q[i]
    aiold=ai(i,market)
    c=(aiold+viold)/2
    market.q[i]=c; market.p[i]=player.x[i].dtheta(c)
    uinew=ui(i,player,market)
    if uinew<=uiold+market.epsilon
        market.q[i]=viold; market.p[i]=player.x[i].dtheta(market.q[i])
        return 0
    end
	market.q[i]=c; market.p[i]=player.x[i].dtheta(c)
    return 1
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

function gubajr(i::Int,player::Player,market::Market)
    r=tieQi(i,market.p[i],market)
	viold=market.q[i]
	c=(viold+r)/2
	if c!=viold
		market.q[i]=c; market.p[i]=player.x[i].dtheta(c)
		return 1
	end
	return 0
end

# We assume player[i]==player2[i] since calling ui2
function trybidi2(i::Int,player::Player,player2::Player,
		market::Market,market2::Market)
    uiold=ui2(i,player,player2,market,market2)
		uP2=uplane2q(i,player,player2,market,market2)
		umaxqq=maximum(uP2[3])
		uP2di=udiag2q(i,player,player2,market,market2)
		umaxdi=maximum(uP2di[2])
    aiold=ai(i,market); aiold2=ai(i,market2)
    viold=market.q[i]; wiold=market.p[i]
    viold2=market2.q[i]; wiold2=market2.p[i]
    zi=min(supGi2(i,player,market,market2),player.x[i].theta.barql)
    vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
    winew=player.x[i].dtheta(vinew)
    # this is the same price in each market rule
	qi1=Qi(i,winew,market); qi2=Qi(i,winew,market2)
	d=qi1+qi2
	if d>0.0
		qi1,qi2=vinew*qi1/d,vinew*qi2/d
	else
		qi1=0.0; qi2=0.0
	end
    market.q[i]=qi1; market.p[i]=winew
    market2.q[i]=qi2; market2.p[i]=winew
    uinew=ui2(i,player,player2,market,market2)
		@printf("uiold=%g uinew=%g umaxqq=%g umaxdi=%g\n",
		uiold,uinew,umaxqq,umaxdi)
    ainew=ai(i,market); ainew2=ai(1,market2)
    @printf("(%g/%g,%g) (%g/%g,%g) %g \n\t-> (%g/%g,%g) (%g/%g,%g) %g ",
        aiold,viold,wiold,aiold2,viold2,wiold2,uiold,
        ainew,market.q[i],market.p[i],ainew2,market2.q[i],market2.p[i],uinew)
   	market.q[i]=viold; market.p[i]=wiold
    market2.q[i]=viold2; market2.p[i]=wiold2
    if uinew>uiold+market.epsilon
        @printf("->\n")
    else
        @printf("\n")
    end
end

# We assume player[i]==player2[i] since calling ui2
function bidi2(i::Int,player::Player,player2::Player,
		market::Market,market2::Market)
    uiold=ui2(i,player,player2,market,market2)
    aiold=ai(i,market); aiold2=ai(i,market2)
    viold=market.q[i]; wiold=market.p[i]
    viold2=market2.q[i]; wiold2=market2.p[i]
    zi=min(supGi2(i,player,market,market2),player.x[i].theta.barql)
    vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
    winew=player.x[i].dtheta(vinew)
    # this is the same price in each market rule
	qi1=Qi(i,winew,market); qi2=Qi(i,winew,market2)
	d=qi1+qi2
	if d>0.0
		qi1,qi2=vinew*qi1/d,vinew*qi2/d
	else
		qi1=0.0; qi2=0.0
	end
    market.q[i]=qi1; market.p[i]=winew
    market2.q[i]=qi2; market2.p[i]=winew
    uinew=ui2(i,player,player2,market,market2)
    ainew=ai(i,market); ainew2=ai(1,market2)
#    @printf("(%g/%g,%g) (%g/%g,%g) %g \n\t-> (%g/%g,%g) (%g/%g,%g) %g ",
#        aiold,viold,wiold,aiold2,viold2,wiold2,uiold,
#        ainew,market.q[i],market.p[i],ainew2,market2.q[i],market2.p[i],uinew)
    if uinew>uiold+market.epsilon
#        @printf("->\n")
		return 1
    else
		if uiold==0
# This is the rule when a player is too generous to get anything
			setfairi2(player,player2,market,market2,i)
#			market.q[i]=0.0; market.p[i]=0
#			market2.q[i]=0.0; market2.p[i]=0
#			market.q[i]=viold; market2.q[i]=viold2
#			market.p[i]=player.x[i].dtheta(market.q[i]+market2.q[i])
#			market2.p[i]=player.x[i].dtheta(market.q[i]+market2.q[i])
		else
    		market.q[i]=viold; market.p[i]=wiold
		    market2.q[i]=viold2; market2.p[i]=wiold2
		end
#		@printf("\n")
		return 0
    end
end

function doround2(player1::Player,player2::Player,
		market1::Market,market2::Market)
	c=0
	NM=length(market1.q)
	for i=1:NM
		if player1.x[i].theta==player2.x[i].theta
			c+=bidi2(i,player1,player2,market1,market2)
		else
			c+=bidi(i,player1,market1)
			c+=bidi(i,player2,market2)
		end
	end
	return c
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

function gubajrround(player::Player,market::Market)
	c=0
	N=length(market.q)
	for i=2:N
		c+=gubajr(i,player,market)
	end
	return c
end

function hround(player::Player,market::Market)
	c=0
	N=length(market.q)
	for i=1:N
		if market.q[i]!=ai(i,market)
			c+=guba(i,player,market)
		else
			c+=bidi(i,player,market)
		end
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
#		myci2=intPi(i,ai(i,market),market)
#		@printf("%3d: %12g %12g %12g %12g %12g %12g\n",
#			i,market.q[i],market.p[i],a,myui,myci,myci2)
	end
	@printf("%3s  %12s %12s %12g\n","","","",at)
	println("  total value: ",tvalue)
	println("total utility: ",tutil)
end

function statplayer2(p1::Player,p2::Player,m1::Market,m2::Market)
	N=length(p1.x)
	cnt=0
	for i=1:N
		if p1.x[i].theta==p2.x[i].theta
			cnt+=1
		end
	end
	myM=cnt÷2
	cnt=0
	p1tot=0.0; v1tot=0.0; c1tot=0; a1zer=0
	p2tot=0.0; v2tot=0.0; c2tot=0; a2zer=0
	for i=1:N
		if p1.x[i].theta==p2.x[i].theta
			cnt+=1
			if cnt<=myM
# This was a buyer originally in market 1
				if ai(i,m1)>0
					p1tot+=m1.p[i]
					v1tot+=m1.p[i]*m1.p[i]
					c1tot+=1
				else
					a1zer+=1
				end
			else
# This was a buyer originally in market 2
				if ai(i,m2)>0
					p2tot+=m2.p[i]
					v2tot+=m2.p[i]*m2.p[i]
					c2tot+=1
				else
					a2zer+=1
				end
			end
		else
			if ai(i,m1)>0
				p1tot+=m1.p[i]
				v1tot+=m1.p[i]*m1.p[i]
				c1tot+=1
			else
				a1zer+=1
			end
			if ai(i,m2)>0
				p2tot+=m2.p[i]
				v2tot+=m2.p[i]*m2.p[i]
				c2tot+=1
			else
				a2zer+=1
			end
		end
	end
	p1avg=p1tot/c1tot; p1var=v1tot/c1tot-p1avg*p1avg
	p2avg=p2tot/c2tot; p2var=v2tot/c2tot-p2avg*p2avg
	return p1avg,p1var,p2avg,p2var,a1zer,a2zer,c1tot,c2tot
end

# E[x]=sum(ai*xi)/sum(ai)
# V[x]=sum(ai*(xi-E[x])^2)/sum(ai)=sum(ai*xi^2)/sum(ai)-E[x]^2
# hatV[x]=sum(ai*(xi-E[x])^2)/(sum(ai)-sum(ai^2)/sum(ai))

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

function statmarket2(p1::Player,p2::Player,m1::Market,m2::Market)
	N=length(p1.x)
	p1tot=0.0; p1max=0.0; p1min=typemax(Float64); v1tot=0.0
	p2tot=0.0; p2max=0.0; p2min=typemax(Float64); v2tot=0.0
	a1tot=0.0; a2tot=0.0; azer=0
	for i=1:N
		ai1=ai(i,m1); ai2=ai(i,m2)
		if p1.x[i].theta==p2.x[i].theta
			if ai1+ai2<0.01
				azer+=1
			end
		end
		if ai1>=0.01
			if m1.p[i]<p1min
				p1min=m1.p[i]
			end
			if m1.p[i]>p1max
				p1max=m1.p[i]
			end
			p1tot+=ai1*m1.p[i]
			v1tot+=ai1*m1.p[i]*m1.p[i]
			a1tot+=ai1
		elseif p1.x[i].theta!=p2.x[i].theta
			azer+=1
		end
		if ai2>=0.01
			if m2.p[i]<p2min
				p2min=m2.p[i]
			end
			if m2.p[i]>p2max
				p2max=m2.p[i]
			end
			p2tot+=ai2*m2.p[i]
			v2tot+=ai2*m2.p[i]*m2.p[i]
			a2tot+=ai2
		elseif p1.x[i].theta!=p2.x[i].theta
			azer+=1
		end
	end
	p1avg=p1tot/a1tot; p1var=v1tot/a1tot-p1avg*p1avg
	p2avg=p2tot/a2tot; p2var=v2tot/a2tot-p2avg*p2avg
	return p1avg,p1var,p2avg,p2var,azer
end

function prplayer(player::Player)
	N=length(player.x)
	@printf("%3s  %12s %12s\n","i","barq","kappa")
	for i=2:N
		@printf("%3d: %12g %12g\n",
			i,player.x[i].theta.barql,player.x[i].theta.kappal)
	end
end

function prmarket2(player1::Player,player2::Player,
		market1::Market,market2::Market)
	@printf("%3s  %12s %12s %12s %12s %12s\n",	
		"i","q","p","a","u","c")
	tvalue=0.0
	tutil=0.0
	NM=length(market1.q)
	at1=0.0; at2=0.0; ctp=0
	for i=1:NM
		if player1.x[i].theta==player2.x[i].theta
			ctp+=1
			a1=ai(i,market1); a2=ai(i,market2); at1+=a1; at2+=a2;
			tvalue+=player1.x[i].theta(a1+a2)
			myui=ui2(i,player1,player2,market1,market2); tutil+=myui
			myci1=ci(i,player1,market1); myci2=ci(i,player1,market2)
			@printf("%3d: %12g %12g %12g %12s %12g\n",
				i,market1.q[i],market1.p[i],a1,"",myci1)
			@printf("%3s  %12g %12g %12g %12g %12g\n",
				"",market2.q[i],market2.p[i],a2,myui,myci2)
		end
	end
	if ctp>0
		@printf("\n");
	end
	at=at1
	function pri(i::Int,player::Player,market::Market)
		a=ai(i,market); at+=a
		tvalue+=player.x[i].theta(a)
		myui=ui(i,player,market); tutil+=myui
		myci=ci(i,player,market)
		@printf("%3d: %12g %12g %12g %12g %12g\n",
			i,market.q[i],market.p[i],a,myui,myci)
	end
	for i=1:NM
		if player1.x[i].theta!=player2.x[i].theta
			pri(i,player1,market1)
		end
	end
	@printf("%3s  %12s %12s %12g\n\n","","","",at)
	at=at2
	for i=1:NM
		if player1.x[i].theta!=player2.x[i].theta
			pri(i,player2,market2)
		end
	end
	@printf("%3s  %12s %12s %12g\n","","","",at)
	println("  total value: ",tvalue)
	println("total utility: ",tutil)
end

function doconv(player::Player,market::Market)
	for l=1:10000
		if doround(player,market)==0
#			println("Converged in $l rounds")
#			prmarket(player,market)
			return l
		end
	end
	println("Didn't converge")
	return 0
end

#= Fido's very own priority queue in Julia =#
mutable struct Node
	t::Float64
	i::Int
	q::Float64
    p::Float64
end
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
        t=pop!(heap)
        if length(heap)==0 return t end
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
            if t.t<=heap[s1].t break end
            heap[s0]=heap[s1]
            s0=s1
        end
        heap[s0]=t
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

function queuebidi(i::Int,player::Player,market::Market,
		enc::Function,dec::Function)
	uiold=ui(i,player,market)
	viold=market.q[i]; wiold=market.p[i]
	zi=min(supGi(i,player,market),player.x[i].theta.barql)
	vinew=max(0.0,zi-market.epsilon/player.x[i].dtheta(0.0))
	winew=player.x[i].dtheta(vinew)
	market.q[i]=vinew; market.p[i]=winew
	uinew=ui(i,player,market)
#	@printf("(%g,%g) %g -> (%g,%g) %g ",
#		viold,wiold,uiold,vinew,winew,uinew)
	if uinew<=uiold+market.epsilon
		if uiold==0
# When a player is too generous to get anything we set the bid
# back to the fair-share price, this trick doesn't work when we
# are dealing with communication latencies and making this one
# message instantaneous is irrational.  FIXME
			setfairi(player,market,i)
		else
			market.q[i]=viold; market.p[i]=wiold
		end
#		@printf("\n")
		return 0
	else
#		@printf("->\n")
		return 1
	end
end

function queueconv(player::Player,market::Market)
	enc,deq=mkpriority()
	N=length(player.x)
	d=market.blambda
	if d>0
		for i=2:N
			t=market.bdelay+rweibull(d,market.bshape)
			enc(Node(t,i,0.0,0.0))
		end
	else
		for i=2:N
			weibull(d,market.bshape)
			t=market.bdelay*(1.0+(i-1)/N)
			enc(Node(t,i,0.0,0.0))
		end
	end
	reply=ones(Int,N); reply[1]=0
	while length(enc.heap)>0
		v=deq()
		function sendbid()
			r=queuebidi(v.i,player,market,enc,deq)
			if r>0
				for i=2:N
					reply[i]=1
				end
			end
			reply[v.i]=0
			if sum(reply)==0
				return false
			end
			v.t+=market.bdelay+rweibull(d,market.bshape)
			enc(v)
			return true
		end
		function receivebid()
			println("Function receivebid is not defined!")
			throw(myexit(1))
		end
		if v.q==0.0
			if !sendbid()
				break
			end
		else
			receivebid()
		end
	end
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

function doconv2(player1::Player,player2::Player,	
		market1::Market,market2::Market)
	for l=1:10000
		if doround2(player1,player2,market1,market2)==0
#			println("Converged in $l rounds")
#			prmarket2(player1,player2,market1,market2)
			return l
		end
	end
	println("Didn't converge")
	return 0
end

function randbids(player::Player,market::Market)
	N=length(market.q)
	for i=2:N
		market.q[i]=rand()*player.x[i].theta.barql
		market.p[i]=player.x[i].dtheta(market.q[i])
	end
end

function fairbids(player::Player,market::Market)
	N=length(market.q)
	for i=2:N
		setfairi(player,market,i)
	end
end

function fairbids2(p1::Player,p2::Player,m1::Market,m2::Market)
	N=length(m1.q)
	for i=1:N
		setfairi2(p1,p2,m1,m2,i)
	end
end

function maxbids(player::Player,market::Market)
	N=length(market.q)
	for i=1:N
		market.q[i]=market.Q
		market.p[i]=player.x[i].dtheta(0.0)
	end
end

function zerobids(player::Player,market::Market)
	N=length(market.q)
	for i=1:N
		market.q[i]=0.0
		market.p[i]=player.x[i].dtheta(market.q[i])
	end
end

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

# for d in 1:360; display(plot(ps,qs,zs,st=:surface,camera=(d,30))); end
function uplane2q(i::Int,player1::Player,player2::Player,
		market1::Market,market2::Market)
	market1mi=deepcopy(market1); market2mi=deepcopy(market2)
	qs=[0:0.5:100.0;]
	zs=zeros(length(qs),length(qs))
	for k=1:length(qs)
		for j=1:length(qs)
			market1mi.q[i]=qs[k]; market2mi.q[i]=qs[j]
			market1mi.p[i]=player1.x[i].dtheta(qs[k])
			market2mi.p[i]=player2.x[i].dtheta(qs[j])
			zs[j,k]=ui2(i,player1,player2,market1mi,market2mi)
		end
	end
	return qs,qs,zs
end

# dtheta(qk+qj)=qk*dtheta(qk)+qj*dtheta(qj)=dtheta(qk^2+qj^2)/(qk+qj)

function udiag2q(i::Int,player1::Player,player2::Player,
		market1::Market,market2::Market)
	market1mi=deepcopy(market1); market2mi=deepcopy(market2)
	qs=[0:0.05:100.0;]
	zs=zeros(length(qs))
	for k=1:length(qs)
		market1mi.q[i]=qs[k]
		market1mi.p[i]=player1.x[i].dtheta(qs[k])
		market2mi.q[i]=qs[k]
		market2mi.p[i]=player2.x[i].dtheta(qs[k])
		zs[k]=ui2(i,player1,player2,market1mi,market2mi)
	end
	return qs,zs
end

# for d in 1:360; display(plot(ps,qs,zs,st=:surface,camera=(d,30))); end
function uplane2p(i::Int,player1::Player,player2::Player,
		market1::Market,market2::Market)
	market1mi=deepcopy(market1); market2mi=deepcopy(market2)
	ps=[0:0.1:15.0;]
	zs=zeros(length(ps),length(ps))
	for k=1:length(ps)
		for j=1:length(ps)
			market1mi.p[i]=ps[k]; market2mi.p[i]=ps[j]
			market1mi.q[i]=player1.x[i].dthetainv(ps[k])
			market2mi.q[i]=player2.x[i].dthetainv(ps[j])
			zs[j,k]=ui2(i,player1,player2,market1mi,market2mi)
		end
	end
	return ps,ps,zs
end

function doinit(scale::Float64=1.0,N::Int=gN)
	player=Player(scale,N)
	market=Market(N)
	randbids(player,market)
	return player,market
end

# Create N players, N scaled players and two markets 
# Make 2*M of the players common to each market
function doinit2(scale::Float64=1.0,M::Int=gM,N::Int=gN)
	player1=Player(1.0,N+M)
	player2=Player(scale,N+M)
	player1.x[1:M]=player2.x[1:M]
	player2.x[M+1:2*M]=player1.x[M+1:2*M]
	market1=Market(M+N)
	market2=Market(M+N); market1.Q*=1
	randbids(player1,market1)
	randbids(player2,market2)
	market1.q[1:2*M]=market2.q[1:2*M]
	market1.p[1:2*M]=market2.p[1:2*M]
	return player1,player2,market1,market2
end

function single(playeru::Player,mQ::Float64=100.0,rbids::Int=0)
	player=deepcopy(playeru)
	myN=length(playeru.x)
	market=Market(myN)
	market.Q=mQ
	if rbids>0
		randbids(player,market)
	else
		fairbids(player,market)
	end
	market.q[1]=mQ; market.p[1]=player.x[1].dtheta(mQ)
	return player,market
end

function combine(p1u::Player,p2u::Player,myM::Int,
		m1Q::Float64=1000.0,m2Q::Float64=2000.0)
    myN=length(p1u.x)
    p1=Player(1.0,myN+myM)
    p1.x[1:myM]=p1u.x[1:myM]
    p1.x[myM+1:2*myM]=p2u.x[1:myM]
    p1.x[2*myM+1:myN+myM]=p1u.x[myM+1:myN]
    m1=Market(myN+myM); m1.Q=m1Q
    p2=Player(1.0,myN+myM)
    p2.x[1:myM]=p1u.x[1:myM]
    p2.x[myM+1:2*myM]=p2u.x[1:myM]
    p2.x[2*myM+1:myN+myM]=p2u.x[myM+1:myN]
    m2=Market(myN+myM); m2.Q=m2Q
    fairbids2(p1,p2,m1,m2)
    return p1,p2,m1,m2
end
