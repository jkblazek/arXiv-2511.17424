# Test for weibull routine in auctlib

include("auctlib.jl")

m=140
b=zeros(m); cb=0
a=zeros(m)
#lambda=0.25; beta=1.5; delay=1.0
lambda=1.00; beta=0.75; delay=0.1
pdf(x)=beta*(1/lambda)^beta*x^(beta-1)*exp(-(x/lambda)^beta)
function w1(x)
	z=x-delay
	if z<0
		return 0
	end
	return pdf(z)
end
for i=1:m
	a[i]=i/50
end

function stats(E::Int=1000)
	global b,cb
	for i=1:E
		r=delay+rweibull(lambda,beta)
		n=Int(floor(r*50))+1
		if n>m
			n=m; cb+=1
		end
		b[n]+=1
	end
	for i=1:m
		b[i]=b[i]/E*50
	end
end

using Statistics, Random, Plots

# From ChatGPT

λ = 1.0
β = 0.75
n = 10^6

z = λ * (-log.(1 .- rand(n))).^(1/β)

# Compare to analytical PDF
pdf(x) = (β/λ) * (x/λ)^(β-1) * exp(-(x/λ)^β)

#histogram(z; norm=true, bins=100, xlims=(0,5), label="samples",
#	xlabel="seconds",ylabel="density",weights=fill(100/n,n))
histogram(z; bins=100, xlims=(0,5), label="samples",
	xlabel="seconds",ylabel="density",weights=fill(100/n,n))
plot!(x -> 100*pdf(x), 0, 3λ; label="theoretical PDF", lw=2)
