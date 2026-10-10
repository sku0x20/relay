FROM alpine:3.24
RUN apk add --no-cache mise
ENV MISE_TRUSTED_CONFIG_PATHS=/app
ENV PATH=/root/.local/share/mise/shims:$PATH
WORKDIR /app
# toolchain version comes from mise.toml; rebuild the image after changing it
COPY mise.toml .
RUN mise install zig
CMD ["sleep", "infinity"]
