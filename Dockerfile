FROM julia:1.10

WORKDIR /app

COPY /src/auctlib.jl /src/seasons.jl /src/util.jl seasons.conf /app/

CMD ["/bin/bash", "-lc", "mkdir -p outputs && julia seasons.jl && cp -r prices.dat time state outputs/ 2>/dev/null || true"]
