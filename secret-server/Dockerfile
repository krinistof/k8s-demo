#!/usr/bin/docker build -t secret-server:latest .
 
FROM rust:1-slim-bookworm AS builder

WORKDIR /usr/src/secret-server

# See .dockerignore
COPY . /usr/src/secret-server

RUN cargo build --release

FROM gcr.io/distroless/cc-debian12

# Copy the compiled binary from the builder stage
COPY --from=builder /usr/src/secret-server/target/release/secret-server /usr/local/bin/secret-server
COPY --from=builder /usr/src/secret-server/Rocket.toml /app/

WORKDIR /app

EXPOSE 80

# Set the entrypoint for the container
ENTRYPOINT ["/usr/local/bin/secret-server"]

