# ================================
# Build image
# ================================
FROM swift:6.0-jammy AS build

WORKDIR /build

# Copy package manifest and resolve dependencies
COPY Package.swift .
RUN swift package resolve

# Copy only source code (not tests)
COPY Sources Sources
RUN swift build -c release --product App

# ================================
# Runtime image
# ================================
FROM ubuntu:22.04 AS runtime

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

COPY --from=build /build/.build/release/App ./App

EXPOSE 8080

ENTRYPOINT ["./App", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
