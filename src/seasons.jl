using Random

struct DoExit <: Exception 
end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
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
	sernash=parse(Int,get(mconf,"sernash","0"))
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
	function prparam(io::IO=Base.stdout)
		@printf(io,"#buyseed=%d\n",mybuyseed)
		@printf(io,"#bidseed=%d\n",mybidseed)
		@printf(io,"#bidstep=%d\n",mybidstep)
		@printf(io,"#comseed=%d\n",mycomseed)
		@printf(io,"#comstep=%d\n",mycomstep)
		@printf(io,"#N=%d\n",myN)
		@printf(io,"#E=%d\n",myE)
		@printf(io,"#Q=%g\n",myQ)
		@printf(io,"#Qbase=%g\n",myQbase)
		@printf(io,"#Qamp=%g\n",myQamp)
		@printf(io,"#Qper=%g\n",myQper)
		@printf(io,"#Qphase=%g\n",myQphase)
		@printf(io,"#Qmin=%g\n",myQmin)
		@printf(io,"#Qdt=%g\n",myQdt)
		@printf(io,"#Tend=%g\n",myTend)
		@printf(io,"#P=%g\n",myP)
		@printf(io,"#greed=%g\n",mgreed)
		@printf(io,"#sernash=%d\n",sernash)
		@printf(io,"#epsilon=%g\n",myeps)
		@printf(io,"#bdelay=%g\n",mybdelay)
		@printf(io,"#blambda=%g\n",myblambda)
		@printf(io,"#bshape=%g\n",mybshape)
		@printf(io,"#cdelay=%g\n",mycdelay)
		@printf(io,"#clambda=%g\n",myclambda)
		@printf(io,"#cshape=%g\n",mycshape)
		@printf(io,"#twins=%g\n",mytwins)
		@printf(io,"#traji=%s\n",string(mytraji))
		@printf(io,"#\n")
		flush(io)
	end
	fp=open("prices.dat","w")
	prparam(); prparam(fp)
	function prheader(io::IO=Base.stdout)
		@printf(io,"#%s %s %s %s %s %s %s %s %s %s\n",
		"e","pavg","pstd","vtot","ctot","utot","az",
		"etime","mcount","bcount")
		flush(io)
	end
	prheader(); prheader(fp)
	Random.seed!(mybuyseed)
	playeru=Player(mgreed,myN+1)
	function rtheta(z::Float64)
		return z*myP
	end
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
	serialize("state/playeru.bin",playeru)
	palcavg=zeros(Float64,myN); palcvar=zeros(Float64,myN)
	pvalavg=zeros(Float64,myN); pvalvar=zeros(Float64,myN)
	pcstavg=zeros(Float64,myN); pcstvar=zeros(Float64,myN)
	putlavg=zeros(Float64,myN); putlvar=zeros(Float64,myN)
	ptavg=0.0; ptvar=0.0; vtavg=0.0; vtvar=0.0
	ctavg=0.0; ctvar=0.0; utavg=0.0; utvar=0.0
	etavg=0.0; etvar=0.0; bcavg=0.0; bcvar=0.0
	for e=1:myE
		Random.seed!(mybidseed+mybidstep*e); rand(7)
		player,market=single(playeru,myQ,mybidseed)
		market.Qbase=myQbase
		market.Qamp=myQamp
		market.Qper=myQper
		market.Qphase=myQphase
		market.Qmin=myQmin
        market.Qdt=myQdt
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
		queueavg(player,market,e)
		if sernash!=0
			open("state/n_$myM.bin","w") do io
				serialize(io,player)
				serialize(io,market)
			end
		end
		for i=1:myN
			mai=ai(i,market)
			mvi=player.x[i].theta(mai)
			mci=ci(i,player,market)
			mui=mvi-mci
			palcavg[i]+=mai; palcvar[i]+=mai*mai
			pvalavg[i]+=mvi; pvalvar[i]+=mvi*mvi
			pcstavg[i]+=mci; pcstvar[i]+=mci*mci
			putlavg[i]+=mui; putlvar[i]+=mui*mui
		end
		pavg,pvar,vtot,ctot,az=statmarket(player,market)
		utot=vtot-ctot
		function prstat(io::IO=Base.stdout)
			@printf(io,"%d %g %g %g %g %g %d %g %d %d\n",
			e,pavg,sqrt(pvar),vtot,ctot,utot,az,
			market.etime,market.mcount,market.bcount)
			flush(io)
		end
		prstat(); prstat(fp)
		tcount+=market.mcount
		ptavg+=pavg; ptvar+=pavg*pavg
		vtavg+=vtot; vtvar+=vtot*vtot
		ctavg+=ctot; ctvar+=ctot*ctot
		utavg+=utot; utvar+=utot*utot
		etavg+=market.etime; etvar+=market.etime^2
		bcavg+=market.bcount; bcvar+=Float64(market.bcount)^2
	end
	ptavg/=myE; vtavg/=myE; ctavg/=myE; utavg/=myE
	etavg/=myE; bcavg/=myE
	ptvar=abs((ptvar-ptavg*ptavg*myE)/(myE-1))
	vtvar=abs((vtvar-vtavg*vtavg*myE)/(myE-1))
	ctvar=abs((ctvar-ctavg*ctavg*myE)/(myE-1))
	utvar=abs((utvar-utavg*utavg*myE)/(myE-1))
	etvar=abs((etvar-etavg*etavg*myE)/(myE-1))
	bcvar=abs((bcvar-bcavg*bcavg*myE)/(myE-1))
	function prfinal(io::IO=Base.stdout)
		@printf(io,"\n\n#%s %s %s %s %s %s %s %s %s %s %s %s\n",
			"ptavg","ptstd","vtavg","vtstd",
			"ctavg","ctstd","utavg","utstd",
			"etavg","etstd","bcavg","bcstd")
		@printf(io,"%g %g %g %g %g %g %g %g %g %g %g %g\n",
			ptavg,sqrt(ptvar),vtavg,sqrt(vtvar),
			ctavg,sqrt(ctvar),utavg,sqrt(utvar),
			etavg,sqrt(etvar),bcavg,sqrt(bcvar))
	end
	prfinal(); prfinal(fp)
	function prstath(io::IO=Base.stdout)
		@printf(io,"\n\n#%s %s %s %s %s %s %s %s %s\n",
			"i","<ai>","std","<vi>","std","<ci>","std","<ui>","std")
	end
	prstath(); prstath(fp)
	for i=1:myN
		palcavg[i]/=myE; pvalavg[i]/=myE
		pcstavg[i]/=myE; putlavg[i]/=myE
		palcvar[i]=abs((palcvar[i]-palcavg[i]^2*myE)/(myE-1))
		pvalvar[i]=abs((pvalvar[i]-pvalavg[i]^2*myE)/(myE-1))
		pcstvar[i]=abs((pcstvar[i]-pcstavg[i]^2*myE)/(myE-1))
		putlvar[i]=abs((putlvar[i]-putlavg[i]^2*myE)/(myE-1))
		function prpstat(io::IO=Base.stdout)
			@printf(io,"%d %g %g %g %g %g %g %g %g\n",
				i,palcavg[i],sqrt(palcvar[i]),
				pvalavg[i],sqrt(pvalvar[i]),
				pcstavg[i],sqrt(pcstvar[i]),
				putlavg[i],sqrt(putlvar[i]))
		end
		prpstat(); prpstat(fp)
	end
	close(fp)
	return tcount
end

function main()
	tcount=0
    tsec=@elapsed try
        println("One Auction Progressive Second Price Market Version 40\n")
#        println("OpenBLAS is using ",BLAS.get_num_threads()," threads.")
#        println("Julia is using ",Threads.nthreads()," threads.\n")
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
