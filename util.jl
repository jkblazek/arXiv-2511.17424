function rconf(s::String)::Dict{String,String}
    data=String[]
    open(s,"r") do fp
        data=readlines(fp)
    end
    mconf=Dict{String,String}()
    for i=1:length(data)
        v=split(data[i],"=";limit=2)
        mconf[v[1]]=v[2]
    end
    return mconf
end
