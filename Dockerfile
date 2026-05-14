FROM julia:1.10

RUN groupadd -g 1000 jblazek && useradd -u 1000 -g 1000 -m jblazek

WORKDIR /app

COPY src /app/src
COPY seasons.conf /app

RUN chown -R jblazek:jblazek /app

USER jblazek

CMD ["/bin/bash", "-c", "mkdir -p outputs && julia src/seasons.jl && cp -r prices.dat time state outputs/ 2>/dev/null || true"]
