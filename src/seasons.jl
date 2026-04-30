using Random

struct DoExit <: Exception 
end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"auctio.jl")
include(mydir*"auctstat.jl")
include(mydir*"auctqueue.jl")
include(mydir*"util.jl")

function dowork()
	tcount=0
	mconf=rconf("seasons.conf")
	mybuyseed=parse(Int,get(mconf,"buyseed","2137"))
	mybidseed=parse(Int,get(mconf,"bidseed","3915"))
	mybidstep=parse(Int,get(mconf,"bidstep","0"))
	mycomseed=parse(Int,get(mconf,"comseed","1673"))
	mycomstep=parse(Int,get(mconf,"comstep","0"))
	myN=parse(Int,get(mconf,"N","100"))
	myE=parse(Int,get(mconf,"E","100"))
	myQ=parse(Float64,get(mconf,"Q","1000.0"))
	myP=parse(Float64,get(mconf,"P","10.0"))
	myQbase=parse(Float64,get(mconf,"Qbase",string(myQ)))
	myQamp=parse(Float64,get(mconf,"Qamp","0.0"))
	myQper=parse(Float64,get(mconf,"Qper","0.0"))
	myQphase=parse(Float64,get(mconf,"Qphase","0.0"))
	myQmin=parse(Float64,get(mconf,"Qmin","0.0"))
	myQdt=parse(Float64,get(mconf,"Qdt","1.0"))
	myTend=parse(Float64,get(mconf,"Tend","-1.0"))
	mgreed=parse(Float64,get(mconf,"greed","1.0"))
	myeps=parse(Float64,get(mconf,"epsilon","5.0"))
	mybdelay=parse(Float64,get(mconf,"bdelay","1.0"))
	myblambda=parse(Float64,get(mconf,"blambda","0.25"))
	mybshape=parse(Float64,get(mconf,"bshape","1.5"))
	mycdelay=parse(Float64,get(mconf,"cdelay","0.1"))
	myclambda=parse(Float64,get(mconf,"clambda","1.0"))
	mycshape=parse(Float64,get(mconf,"cshape","0.75"))
	mytwins=parse(Float64,get(mconf,"twins","0.0"))
	mytrajis=split(get(mconf,"traji",""),",")
	mytraji=zeros(Int,0)
	if mytrajis[1]!=""
		mytraji=parse.(Int,mytrajis)
	end
	Random.seed!(mybuyseed)
	playeru=Player(mgreed,myN+1)
	playeru.x[1]=Buyer(z->z*myP,z->myP,z->NaN,Inf)
	myN+=1  # add the reserve buyer
	if mytwins>0
		if (myN-1)%2==1
			println("No twins with odd ",myN-1," number of buyers!")
			throw(DoExit(1))
		end
		myN2=(myN-1)÷2
		for i=2:myN2+1
			playeru.x[i+myN2]=deepcopy(playeru.x[i])
		end
	end
	mkpath("state")
	save_playeru("state/playeru.dat", playeru)
	etimes=zeros(Float64,myE)
	mcounts=zeros(Int,myE)
	bcounts=zeros(Int,myE)
	for e=1:myE
		Random.seed!(mybidseed+mybidstep*e); rand(7)
		player,market=single(playeru,myQ,mybidseed)
		market.Qbase=myQbase; market.Qamp=myQamp
		market.Qper=myQper; market.Qphase=myQphase
		market.Qmin=myQmin; market.Qdt=myQdt
		market.Tend=myTend
		if mytwins>0
			myN2=(myN-1)÷2
			for i=2:myN2+1
				market.q[i+myN2]=market.q[i]
				market.p[i+myN2]=market.p[i]
			end
		end
		market.epsilon=myeps; market.twins=mytwins
		market.bdelay=mybdelay
		market.blambda=myblambda; market.bshape=mybshape
		market.cdelay=mycdelay
		market.clambda=myclambda; market.cshape=mycshape
		market.traji=mytraji
		Random.seed!(mycomseed+mycomstep*e); rand(7)
		phasefp::Union{IO,Nothing}=nothing
		if market.Qper>0.0
			mkpath("state")
			phasefp=open(@sprintf("state/phase_%03d.dat",e),"w")
			@printf(phasefp,"#cycle t Q i q p a\n"); flush(phasefp)
		end
		queueavg(player,market,e,phasefp)
		if phasefp !== nothing; close(phasefp); end
		etimes[e]=market.etime
		mcounts[e]=market.mcount
		bcounts[e]=market.bcount
		tcount+=market.mcount
	end
	# write metadata for auctstat.jl
	open("state/runmeta.dat","w") do io
		@printf(io,"#e etime mcount bcount\n")
		for e=1:myE
			@printf(io,"%d %g %d %d\n",e,etimes[e],mcounts[e],bcounts[e])
		end
	end
	return tcount
end

function main()
	tcount=0
	tsec=@elapsed try
		println("One Auction Progressive Second Price Market Version 45\n")
		tcount=dowork()
		throw(DoExit())
	catch r
		if !isa(r,DoExit)
			rethrow(r)
		end
	end
	println("\nMarket evaluation rate is ",tcount/tsec," per second.")
	println("Total execution time ",tsec," seconds.")
end

main()

