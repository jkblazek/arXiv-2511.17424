using Printf

struct DoExit <: Exception end

mydir=@__DIR__; mydir=mydir*"/"
include(mydir*"auctlib.jl")
include(mydir*"auctio.jl")
include(mydir*"auctstat.jl")
include(mydir*"util.jl")

# Driver: compute time-averaged utility ± time-deviation for a single run,
# or ensemble mean ± ensemble std across all runs (mode="ensemble").
# Reads: <conf>, time/traj*.dat
# Writes: twins_avg.dat, twins_avg.gp
#
# Usage: julia src/twins_stat.jl <conf> <outdir> [run=N|ensemble]
#   run=N    — single run N, plots time-avg ± time-dev  (default: run=1)
#   ensemble — average over all E runs, plots ensemble mean ± ensemble std

function dotwins(conf::String, outdir::String=".", mode::String="run=1")
	mconf=rconf(conf)
	myN=parse(Int,get(mconf,"N","100"))
	myE=parse(Int,get(mconf,"E","1"))
	mytwins=parse(Float64,get(mconf,"twins","0.0"))
	myQper=parse(Float64,get(mconf,"Qper","0.0"))
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

	N2=(myN-1)÷2
	industrious=sort(filter(i->i>=2 && i<=N2+1, mytraji))
	lazy       =sort(filter(i->i> N2+1,          mytraji))
	if isempty(industrious) || isempty(lazy)
		println("Could not split traji into twin pairs — check traji and N.")
		return
	end
	npairs=min(length(industrious),length(lazy))

	u_mean=Dict{Int,Float64}()
	u_dev =Dict{Int,Float64}()

    # time-avg ± time-dev from traj_timeavg
    e=parse(Int,mode[5:end])
    path=joinpath(outdir,@sprintf("time/traj%03d.dat",e))
    if !isfile(path)
        println("Missing $path")
        return
    end
    tvec,Qvec,buyers,data=load_traj(path)
    avg,_,dev=traj_timeavg(tvec,Qvec,buyers,data,myQper)
    for i in mytraji
        u_mean[i]=haskey(avg,i) ? avg[i][4] : 0.0
        u_dev[i] =haskey(dev,i) ? dev[i]    : 0.0
    end
    ylabel="time-avg utility ± time-dev (run $e)"

	fp=open(joinpath(outdir,"twins_avg.dat"),"w")
	@printf(fp,"#buyer ind_u ind_dev lazy_u lazy_dev\n")
	for k=1:npairs
		ii=industrious[k]; il=lazy[k]
		@printf(fp,"%d %g %g %g %g\n",
			ii, u_mean[ii], u_dev[ii], u_mean[il], u_dev[il])
	end
	close(fp)
	println("Wrote twins_avg.dat ($npairs twin pairs)")

	datpath=joinpath(outdir,"twins_avg.dat")
	gppath =joinpath(outdir,"twins_avg.gp")
	gp=open(gppath,"w")
	write(gp,"""
set terminal postscript eps enhanced color font "Helvetica,12"
set output "$(joinpath(outdir,"twins_avg.eps"))"

set xlabel "buyer number"
set ylabel "$ylabel"
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
	mode  = length(ARGS) > 2 ? ARGS[3] : "run=1"
	try
		dotwins(conf, outdir, mode)
		throw(DoExit())
	catch r
		if !isa(r,DoExit)
			rethrow(r)
		end
	end
end

main()
