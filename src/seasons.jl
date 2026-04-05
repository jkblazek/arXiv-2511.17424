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
	myeps=parse(Float64,get(mconf,"epsilon","5.0"))
	mybdelay=parse(Float64,get(mconf,"bdelay","1.0"))
	myblambda=parse(Float64,get(mconf,"blambda","0.25"))
	mybshape=parse(Float64,get(mconf,"bshape","1.5"))
	mycdelay=parse(Float64,get(mconf,"cdelay","0.1"))
	myclambda=parse(Float64,get(mconf,"clambda","1.0"))
	mycshape=parse(Float64,get(mconf,"cshape","0.75"))
	mytwins=parse(Float64,get(mconf,"twins","0.0"))
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
		@printf(io,"#epsilon=%g\n",myeps)
		@printf(io,"#bdelay=%g\n",mybdelay)
		@printf(io,"#blambda=%g\n",myblambda)
		@printf(io,"#bshape=%g\n",mybshape)
		@printf(io,"#cdelay=%g\n",mycdelay)
		@printf(io,"#clambda=%g\n",myclambda)
		@printf(io,"#cshape=%g\n",mycshape)
		@printf(io,"#twins=%g\n",mytwins)
		@printf(io,"#\n")
		flush(io)
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

	# --- simulation loop ---
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
		market.traji=collect(1:myN)
		Random.seed!(mycomseed+mycomstep*e); rand(7)
		phasefp::Union{IO,Nothing}=nothing
		if market.Qper>0.0
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

	# --- post-processing: time-weighted averages from traj files ---
	palcavg=zeros(Float64,myN); palcvar=zeros(Float64,myN)
	pvalavg=zeros(Float64,myN); pvalvar=zeros(Float64,myN)
	pcstavg=zeros(Float64,myN); pcstvar=zeros(Float64,myN)
	putlavg=zeros(Float64,myN); putlvar=zeros(Float64,myN)
	ptavg=0.0; ptvar=0.0; vtavg=0.0; vtvar=0.0
	ctavg=0.0; ctvar=0.0; utavg=0.0; utvar=0.0
	etavg=0.0; etvar=0.0; bcavg=0.0; bcvar=0.0
	fp=open("prices.dat","w")
	prparam(); prparam(fp)
	@printf(fp,"#%s %s %s %s %s %s %s %s %s %s\n",
		"e","pavg","pstd","vtot","ctot","utot","az","etime","mcount","bcount")
	for e=1:myE
		tvec,Qvec,data=load_traj(@sprintf("time/traj%03d.dat",e))
		pavg,pvar,a_avg,v_avg,c_avg,u_avg,az=traj_timeavg(tvec,Qvec,data,playeru)
		vtot=sum(v_avg); ctot=sum(c_avg); utot=vtot-ctot
		for i=1:myN
			palcavg[i]+=a_avg[i]; palcvar[i]+=a_avg[i]^2
			pvalavg[i]+=v_avg[i]; pvalvar[i]+=v_avg[i]^2
			pcstavg[i]+=c_avg[i]; pcstvar[i]+=c_avg[i]^2
			putlavg[i]+=u_avg[i]; putlvar[i]+=u_avg[i]^2
		end
		@printf(fp,"%d %g %g %g %g %g %d %g %d %d\n",
			e,pavg,sqrt(pvar),vtot,ctot,utot,az,
			etimes[e],mcounts[e],bcounts[e])
		flush(fp)
		ptavg+=pavg; ptvar+=pavg^2
		vtavg+=vtot; vtvar+=vtot^2
		ctavg+=ctot; ctvar+=ctot^2
		utavg+=utot; utvar+=utot^2
		etavg+=etimes[e]; etvar+=etimes[e]^2
		bcavg+=bcounts[e]; bcvar+=Float64(bcounts[e])^2
	end
	ptavg/=myE; vtavg/=myE; ctavg/=myE; utavg/=myE
	etavg/=myE; bcavg/=myE
	ptvar=abs((ptvar-ptavg^2*myE)/(myE-1))
	vtvar=abs((vtvar-vtavg^2*myE)/(myE-1))
	ctvar=abs((ctvar-ctavg^2*myE)/(myE-1))
	utvar=abs((utvar-utavg^2*myE)/(myE-1))
	etvar=abs((etvar-etavg^2*myE)/(myE-1))
	bcvar=abs((bcvar-bcavg^2*myE)/(myE-1))
	@printf(fp,"\n\n#%s %s %s %s %s %s %s %s %s %s %s %s\n",
		"ptavg","ptstd","vtavg","vtstd","ctavg","ctstd",
		"utavg","utstd","etavg","etstd","bcavg","bcstd")
	@printf(fp,"%g %g %g %g %g %g %g %g %g %g %g %g\n",
		ptavg,sqrt(ptvar),vtavg,sqrt(vtvar),
		ctavg,sqrt(ctvar),utavg,sqrt(utvar),
		etavg,sqrt(etvar),bcavg,sqrt(bcvar))
	@printf(fp,"\n\n#%s %s %s %s %s %s %s %s %s\n",
		"i","<ai>","std","<vi>","std","<ci>","std","<ui>","std")
	for i=1:myN
		palcavg[i]/=myE; pvalavg[i]/=myE
		pcstavg[i]/=myE; putlavg[i]/=myE
		palcvar[i]=abs((palcvar[i]-palcavg[i]^2*myE)/(myE-1))
		pvalvar[i]=abs((pvalvar[i]-pvalavg[i]^2*myE)/(myE-1))
		pcstvar[i]=abs((pcstvar[i]-pcstavg[i]^2*myE)/(myE-1))
		putlvar[i]=abs((putlvar[i]-putlavg[i]^2*myE)/(myE-1))
		@printf(fp,"%d %g %g %g %g %g %g %g %g\n",
			i,palcavg[i],sqrt(palcvar[i]),
			pvalavg[i],sqrt(pvalvar[i]),
			pcstavg[i],sqrt(pcstvar[i]),
			putlavg[i],sqrt(putlvar[i]))
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
