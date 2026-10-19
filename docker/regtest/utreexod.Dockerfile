# utreexod (utreexo proof 인덱스를 가진 브릿지 노드) 빌드.
# Floresta는 utreexo 정합성을 요구하지만 bitcoind는 accumulator/proof를 만들지 않으므로
# utreexod가 bitcoind ↔ florestad 사이에서 proof를 제공한다.
FROM golang:1.25-bookworm AS builder
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
ARG UTREEXOD_REPO=https://github.com/utreexo/utreexod
RUN git clone --depth 1 "${UTREEXOD_REPO}" /src
WORKDIR /src
RUN go build -o /out/utreexod .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /out/utreexod /usr/local/bin/utreexod
VOLUME ["/data"]
ENTRYPOINT ["utreexod"]
