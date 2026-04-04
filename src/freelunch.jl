using Random

struct DoExit <: Exception 
end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"util.jl")

function dowork()
	mconf=rconf("freelunch.conf")
	mybuyseed=parse(Int,get(mconf,"buyseed","2137"))
	mybidseed=parse(Int,get(mconf,"bidseed","3915"))
	mybidstep=parse(Int,get(mconf,"bidstep","0"))
	mycomseed=parse(Int,get(mconf,"comseed","1673"))
	mycomstep=parse(Int,get(mconf,"comstep","0"))
	myN=parse(Int,get(mconf,"N","100"))
	myE=parse(Int,get(mconf,"E","100"))
	myQ=parse(Float64,get(mconf,"Q","1000.0"))
	myP=parse(Float64,get(mconf,"P","10.0"))
	mgreed=parse(Float64,get(mconf,"greed","1.0"))
	sernash=parse(Int,get(mconf,"sernash","0"))
	myeps=parse(Float64,get(mconf,"epsilon","5.0"))	
	mybdelay=parse(Float64,get(mconf,"bdelay","1.0"))
	myblambda=parse(Float64,get(mconf,"blambda","0.25"))
	mybshape=parse(Float64,get(mconf,"bshape","1.5"))
	mycdelay=parse(Float64,get(mconf,"cdelay","0.1"))
	myclambda=parse(Float64,get(mconf,"clambda","1.0"))
	mycshape=parse(Float64,get(mconf,"cshape","0.75"))
	function prparam(io::IO=Base.stdout)
		@printf(io,"#buyseed=%d\n",mybuyseed)
		@printf(io,"#bidseed=%d\n",mybidseed)
		@printf(io,"#bidstep=%d\n",mybidstep)
		@printf(io,"#comseed=%d\n",mycomseed)
		@printf(io,"#comstep=%d\n",mycomstep)
		@printf(io,"#N=%d\n",myN)
		@printf(io,"#E=%d\n",myE)
		@printf(io,"#Q=%g\n",myQ)
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
		@printf(io,"#\n")
		flush(io)
	end
	fp=open("prices.dat","w")
	prparam(); prparam(fp)
	function prheader(io::IO=Base.stdout)
		@printf(io,"#%s %s %s %s %s %s %s\n",
		"e","pavg","pstd","vtot","ctot","utot","az")
		flush(io)
	end
	prheader(); prheader(fp)
	Random.seed!(mybuyseed)
	playeru=Player(mgreed,myN+1)
	function rtheta(z::Float64)
		return z*myP
	end
	playeru.x[1]=Buyer(z->z*myP,z->myP,z->NaN,Inf)
	mkpath("state")
	save_playeru("state/playeru.dat", playeru)
	palcavg=zeros(Float64,myN); palcvar=zeros(Float64,myN)
	pvalavg=zeros(Float64,myN); pvalvar=zeros(Float64,myN)
	pcstavg=zeros(Float64,myN); pcstvar=zeros(Float64,myN)
	putlavg=zeros(Float64,myN); putlvar=zeros(Float64,myN)
	ptavg=0.0; ptvar=0.0; vtavg=0.0; vtvar=0.0
	ctavg=0.0; ctvar=0.0; utavg=0.0; utvar=0.0
	for e=1:myE
		Random.seed!(mybidseed+mybidstep*e); rand(7)
		player,market=single(playeru,myQ,mybidseed)
		market.epsilon=myeps
		market.bdelay=mybdelay
		market.blambda=myblambda; market.bshape=mybshape
		market.cdelay=mycdelay
		market.clambda=myclambda; market.cshape=mycshape
		Random.seed!(mycomseed+mycomstep*e); rand(7)
		for j=1:200
			doround(player,market) # round robin epsilon-best for everyone
			gubaround(player,market) # compromise bids everyone
		end	
		if sernash!=0
			save_nash(@sprintf("state/n_%03d.dat",e), e, player, market)
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
			@printf(io,"%d %g %g %g %g %g %d\n",
			e,pavg,sqrt(pvar),vtot,ctot,utot,az)
			flush(io)
		end
		prstat(); prstat(fp)
		ptavg+=pavg; ptvar+=pavg*pavg
		vtavg+=vtot; vtvar+=vtot*vtot
		ctavg+=ctot; ctvar+=ctot*ctot
		utavg+=utot; utvar+=utot*utot
	end
	ptavg/=myE; vtavg/=myE; ctavg/=myE; utavg/=myE
	ptvar=abs((ptvar-ptavg*ptavg*myE)/(myE-1))
	vtvar=abs((vtvar-vtavg*vtavg*myE)/(myE-1))
	ctvar=abs((ctvar-ctavg*ctavg*myE)/(myE-1))
	utvar=abs((utvar-utavg*utavg*myE)/(myE-1))
	function prfinal(io::IO=Base.stdout)
		@printf(io,"\n\n\n#%s %s %s %s %s %s %s %s\n",
			"ptavg","ptstd","vtavg","vtstd",
			"ctavg","ctstd","utavg","utstd")
		@printf(io,"%g %g %g %g %g %g %g %g\n",
			ptavg,sqrt(ptvar),vtavg,sqrt(vtvar),
			ctavg,sqrt(ctvar),utavg,sqrt(utvar))
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
end

function main()
    t=@elapsed try
        println("Free Lunch Progressive Second Price Market Version 39\n")
#        println("OpenBLAS is using ",BLAS.get_num_threads()," threads.")
#        println("Julia is using ",Threads.nthreads()," threads.\n")
        dowork()
        throw(DoExit())
    catch r
        if !isa(r,DoExit)
            rethrow(r)
        end
    end
    println("\nTotal execution time ",t," seconds.")
end 
    
main()
