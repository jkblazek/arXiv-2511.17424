function pdf(x,lambda,shape)
	if x<=0.0
		return 0.0
	end
	return shape*(1/lambda)^shape*x^(shape-1)*exp(-(x/lambda)^shape)
end
using Plots
plot(x->pdf(x,0.25,1.5),0:0.05:5)
