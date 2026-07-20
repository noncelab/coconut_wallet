FROM --platform=linux/amd64 ubuntu:22.04

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /simulator

# Simulator binary will be mounted/copied
COPY bitbox02-simulator /simulator/bitbox02-simulator
RUN chmod +x /simulator/bitbox02-simulator

EXPOSE 15423

CMD ["/simulator/bitbox02-simulator"]
