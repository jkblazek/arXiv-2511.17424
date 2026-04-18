using Printf

# Event-driven simulation loops.
# Requires: auctlib.jl, auctio.jl

# Convergent auction: runs until epsilon-Nash equilibrium is reached.
# Writes traj file for buyers in market.traji if set.
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
			if trajfp !== nothing
				logstate(trajfp,v.t,player,market)
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
	if trajfp !== nothing
		close(trajfp)
	end
	return 0
end

# Time-horizon auction: runs until market.Tend, with optional oscillating supply.
# Writes traj file for buyers in market.traji if set.
# Writes phase snapshots to phasefp at each integer multiple of Qper if provided.
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
	phase_cycle=0
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
			if trajfp !== nothing
				logstate(trajfp,v.t,player,market)
			end
		end
	end
	if trajfp !== nothing
		close(trajfp)
	end
	return 0
end
