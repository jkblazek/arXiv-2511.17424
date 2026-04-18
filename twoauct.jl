using Random

struct DoExit <: Exception 
end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"util.jl")

function dowork()
	mconf=rconf("twoauct.conf")
	myseed=parse(Int,get(mconf,"seed","2137"))
	myN=parse(Int,get(mconf,"N","100"))
	m1Q=parse(Float64,get(mconf,"Q1","1000.0"))
	m2Q=parse(Float64,get(mconf,"Q2","2000.0"))
	m1greed=parse(Float64,get(mconf,"greed1","1.0"))
	m2greed=parse(Float64,get(mconf,"greed2","1.0"))
	sernash=parse(Int,get(mconf,"sernash","0"))
	myeps=parse(Float64,get(mconf,"epsilon","5.0"))

	Random.seed!(myseed)
	p1u=Player(m1greed,myN)
	p2u=Player(m2greed,myN)
	mkpath("state")
	serialize("state/p1u.bin",p1u)
	serialize("state/p2u.bin",p1u)
	function prparam(io::IO=Base.stdout)
		@printf(io,"#seed=%d\n",myseed)
		@printf(io,"#N=%d\n",myN)
		@printf(io,"#Q1=%g\n",m1Q)
		@printf(io,"#Q2=%g\n",m2Q)
		@printf(io,"#greed1=%g\n",m1greed)
		@printf(io,"#greed2=%g\n",m2greed)
		@printf(io,"#sernash=%d\n",sernash)
		@printf(io,"#epsilon=%g\n",myeps)
		@printf(io,"#\n")
		flush(io)
	end
	fp=open("prices.dat","w")
	prparam(); prparam(fp)
	function prheader(io::IO=Base.stdout)
		@printf(io,"#%s %s %s %s %s %s\n",
		"M","p1avg","p1std","p2avg","p2std","az")
		flush(io)
	end
	prheader(); prheader(fp)
	for myM=0:1:myN
		p1,p2,m1,m2=combine(p1u,p2u,myM,m1Q,m2Q)
		m1.epsilon=myeps; m2.epsilon=myeps
		doconv2(p1,p2,m1,m2)
		if sernash!=0
			open("state/n_$myM.bin","w") do io
				serialize(io,p1)
				serialize(io,p2)
				serialize(io,m1)
				serialize(io,m1)
			end
		end
		p1a,p1v,p2a,p2v,az=statmarket2(p1,p2,m1,m2)
		function prstat(io::IO=Base.stdout)
			@printf(io,"%d %g %g %g %g %d\n",
			myM,p1a,sqrt(p1v),p2a,sqrt(p2v),az)
			flush(io)
		end
		prstat(); prstat(fp)
	end
	close(fp)
end

function main()
    t=@elapsed try
        println("Two Auction Progressive Second Price Market Version 25\n")
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
