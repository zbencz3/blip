# ================================
# Build image
# ================================
FROM swift:6.0-jammy AS build

WORKDIR /build

COPY Package.swift .
RUN swift package resolve

COPY Sources Sources
RUN mkdir -p Tests/AppTests && echo "// placeholder" > Tests/AppTests/Placeholder.swift
RUN swift build -c release --product App

# ================================
# Runtime image (includes Swift runtime libs)
# ================================
FROM swift:6.0-jammy-slim

RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /build/.build/release/App ./App

EXPOSE 8080

ENTRYPOINT ["./App", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
