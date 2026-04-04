# ================================
# Build image
# ================================
FROM swift:6.0-jammy AS build

WORKDIR /build

# Copy package manifests and resolve dependencies first (better layer caching)
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Copy the rest of the source and build in release mode
COPY Sources Sources
COPY Tests Tests
RUN swift build -c release --product App

# ================================
# Runtime image
# ================================
FROM ubuntu:22.04 AS runtime

# Install Swift runtime dependencies
RUN apt-get update && apt-get install -y \
    libatomic1 \
    libcurl4 \
    libxml2 \
    libc6 \
    libgcc-s1 \
    libstdc++6 \
    zlib1g \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built executable and any resources
COPY --from=build /build/.build/release/App ./App

EXPOSE 8080

ENTRYPOINT ["./App", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
