    FROM rust:1-slim-bookworm as builder

    WORKDIR /usr/src/secret-server

    COPY Cargo.toml Cargo.lock ./
    RUN mkdir src && echo "fn main() {}" > src/main.rs
    RUN cargo build --release
    RUN rm -rf src

    COPY ./src ./src
    COPY ./templates ./templates
    COPY Rocket.toml ./Rocket.toml

    RUN cargo build --release

    FROM gcr.io/distroless/cc-debian12

    COPY --from=builder /usr/src/secret-server/target/release/secret-server /usr/local/bin/secret-server
    COPY --from=builder /usr/src/secret-server/Rocket.toml /app/Rocket.toml

    # Set working directory for Rocket to find Rocket.toml and templates/
    WORKDIR /app

    # Expose the port Rocket will listen on (configured in Rocket.toml)
    EXPOSE 80

    # Set the entrypoint for the container
    ENTRYPOINT ["/usr/local/bin/secret-server"]
    
