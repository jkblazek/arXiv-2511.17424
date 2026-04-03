
This is a list of options and default values for the oneauct.conf
configuration file:

seed -- Defaults to 2137 and is used to construct the price
valuation curves of the buyers.

jseed -- Defaults to 3915 and is used to construct the ensembles
through jitter, delay and initial bid.

N -- Defaults to 100 and is the number of buyers in the auction.

E -- Defaults to 100 and represents the size of the ensemble.

Q -- Defaults to 1000.0 and represents the amount of resource that
is available over each time period in the auction.

greed -- Defaults to 1.0.  Larger values result in greedy players
with a high valuation of the resource.  Smaller values result in
generous players who don't care enough to.

sernash -- Defaults to 0.  If zero do nothing.  If non-zero write 
out all the Nash equilibriums in a file.  It is planned to make a
program that checks the Nash equilibrium later.

epsilon -- Defaults to 5.0.  This is the bid price.

period -- Defaults to 1.  How often the buyers check to update their
bids.

jitter -- Defaults to 0.5.  The actual times that a specific buyer
check their bids is period+jitter*(U-1)  where U is a uniform 
random variable on the unit interval.

delay -- Defaults to 0.0.  Delay in bid message communication.

lambda -- Defaults to 1.0  Amplitude in "message communication.

shape -- Defaults to 1.0.  Shape parameter shape>1 is traffic shapping
and buffering, whereas shape<1 implies bursty traffic with long tails.


Oscillatory supply (non-convergent runs)
--------------------------------------
In oneauct.conf you can enable a time-varying total supply Q(t) by setting:
  Qbase  baseline supply (defaults to Q)
  Qamp   fractional amplitude (0 disables)
  Qper   period in simulation time units (0 disables)
  Qphase phase shift (radians)
  Qmin   minimum absolute clamp (optional)

To run for a fixed horizon instead of stopping at convergence, set:
  Tend   time horizon (<=0 keeps the original convergence stopping rule)
