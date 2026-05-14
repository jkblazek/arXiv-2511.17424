using Printf

struct DoExit <: Exception end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"auctio.jl")
include(mydir*"auctstat.jl")
include(mydir*"util.jl")

# Driver: compute time-averaged utility per buyer across ensemble runs,
# then write twins comparison data and gnuplot script.
# Reads: <conf>, state/playeru.dat, time/traj*.dat
# Writes: twins_avg.dat, twins_avg.gp

function dotwins(conf::String, outdir::String=".")
	mconf=rconf(conf)
	myN=parse(Int,get(mconf,"N","100"))
	myE=parse(Int,get(mconf,"E","100"))
	myP=parse(Float64,get(mconf,"P","10.0"))
	mgreed=parse(Float64,get(mconf,"greed","1.0"))
	mytwins=parse(Float64,get(mconf,"twins","0.0"))
	mytrajis=split(get(mconf,"traji",""),",")
	mytraji=zeros(Int,0)
	if mytrajis[1]!=""
		mytraji=parse.(Int,mytrajis)
	end
	myN+=1  # reserve buyer

	if mytwins==0.0
		println("twins=0 in $conf — no twin comparison to make.")
		return
	end
	if isempty(mytraji)
		println("traji not set in $conf — no buyers to analyse.")
		return
	end

	playeru=load_playeru(joinpath(outdir,"state/playeru.dat"), myP, mgreed)

	# u_avg[e, i] = time-avg utility for buyer i in run e
	# only for buyers in mytraji
	u_runs=Dict(i => zeros(Float64, myE) for i in mytraji)

	for e=1:myE
		path=joinpath(outdir,@sprintf("time/traj%03d.dat",e))
		if !isfile(path)
			println("Missing $path, skipping.")
			continue
		end
		tvec,Qvec,buyers,data=load_traj(path)
		_,_,avg=traj_timeavg(tvec,Qvec,buyers,data,nothing)
		for i in mytraji
			if haskey(avg,i)
				u_runs[i][e]=avg[i][4]  # field 4 = u
			end
		end
	end

	# Compute mean and std across ensemble for each buyer
	u_mean=Dict(i => sum(u_runs[i])/myE for i in mytraji)
	u_std =Dict(i => sqrt(max(0.0,
		sum((u_runs[i][e]-u_mean[i])^2 for e=1:myE)/(myE-1)))
		for i in mytraji)

	# Split into industrious and lazy halves based on index
	# Industrious: i <= N/2+1, lazy: i > N/2+1 (same split as twins logic)
	N2=(myN-1)÷2
	industrious=sort(filter(i->i>=2 && i<=N2+1, mytraji))
	lazy       =sort(filter(i->i> N2+1,          mytraji))

	if isempty(industrious) || isempty(lazy)
		println("Could not split traji into twin pairs — check traji and N.")
		return
	end

	# Write data file: industrious buyer index, industrious u ± std, lazy u ± std
	# x-axis is the industrious buyer's own index (matches Fig. 3 right labeling)
	fp=open(joinpath(outdir,"twins_avg.dat"),"w")
	@printf(fp,"#buyer ind_u ind_std lazy_u lazy_std\n")
	npairs=min(length(industrious),length(lazy))
	for k=1:npairs
		ii=industrious[k]; il=lazy[k]
		@printf(fp,"%d %g %g %g %g\n",
			ii, u_mean[ii], u_std[ii], u_mean[il], u_std[il])
	end
	close(fp)
	println("Wrote twins_avg.dat ($npairs twin pairs)")

	# Write gnuplot script
	datpath=joinpath(outdir,"twins_avg.dat")
	gppath =joinpath(outdir,"twins_avg.gp")
	gp=open(gppath,"w")
	write(gp,"""
set terminal postscript eps enhanced color font "Helvetica,12"
set output "$(joinpath(outdir,"twins_avg.eps"))"

set xlabel "buyer number"
set ylabel "average utility with deviation"
set key top left
set datafile commentschars "#"

plot "$(datpath)" using 1:2:3 title "industrious" with yerrorbars pt 4 lc rgb "purple", \\
     "$(datpath)" using 1:4:5 title "$(round(Int,mytwins))x lazier"  with yerrorbars pt 6 lc rgb "green"
""")
	close(gp)
	println("Wrote $gppath")
	println("Run: gnuplot $gppath")
end

function main()
	conf  = length(ARGS) > 0 ? ARGS[1] : "oneauct.conf"
	outdir= length(ARGS) > 1 ? ARGS[2] : "."
	try
		dotwins(conf, outdir)
		throw(DoExit())
	catch r
		if !isa(r,DoExit)
			rethrow(r)
		end
	end
end

main()
