# Blockstream's electrs, built with `electrum-discovery` so it answers
# server.features (Coconut uses it for genesis checks). Serves Electrum on
# 50001 for Coconut and Esplora REST for bark.
FROM docker.io/rust:1.92-bookworm AS builder

RUN apt-get update && apt-get install -y clang cmake && rm -rf /var/lib/apt/lists/*

ARG ELECTRS_REV=16b61e13d8d05bfb2ccfde0923ddb33106520d25
WORKDIR /src
RUN git clone https://github.com/Blockstream/electrs.git . && git checkout "$ELECTRS_REV"
RUN cargo build --release --locked --features electrum-discovery --bin electrs

FROM docker.io/debian:bookworm-slim

COPY --from=builder /src/target/release/electrs /usr/local/bin/electrs
ENTRYPOINT ["electrs"]
