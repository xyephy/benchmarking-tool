############################
# Docker build environment #
############################
FROM ubuntu:22.04 AS build

# Install build dependencies
RUN apt-get update || true && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    yasm \
    libzmq3-dev \
    git \
    autotools-dev \
    autoconf \
    automake \
    pkg-config \
    libtool \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy pre-cloned solo-ckpool source
WORKDIR /build
COPY solo-ckpool-source/ ckpool-solo/

WORKDIR /build/ckpool-solo

# Build ckpool-solo
RUN ./autogen.sh && \
    ./configure && \
    make

############################
# Docker runtime environment #
############################
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libzmq5 \
    iproute2 \
    iputils-ping \
    curl \
    jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy built binaries
COPY --from=build /build/ckpool-solo/src/ckpool /usr/local/bin/
COPY --from=build /build/ckpool-solo/src/ckpmsg /usr/local/bin/

# Copy the monitoring script and startup script
COPY ./pools-latency-calculator/monitor_and_apply_latency.sh /usr/local/bin/monitor_and_apply_latency.sh
COPY ./start-ckpool.sh /usr/local/bin/start-ckpool.sh
RUN chmod +x /usr/local/bin/monitor_and_apply_latency.sh /usr/local/bin/start-ckpool.sh

# Create required directories
RUN mkdir -p /var/log/ckpool /etc/ckpool

# Set working directory
WORKDIR /etc/ckpool

# Expose stratum port
EXPOSE 3333

# Default command - will be overridden by docker-compose
CMD ["/usr/local/bin/ckpool", "-B", "-c", "/etc/ckpool/ckpool.conf"]