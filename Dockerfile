FROM julia:1.10

WORKDIR /app

COPY src /app/src
COPY experiments/seasons.conf /app

CMD ["/bin/bash", "-c", "mkdir -p outputs && julia src/seasons.jl && cp -r prices.dat time state outputs/ 2>/dev/null || true"]
