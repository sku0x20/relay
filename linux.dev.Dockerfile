FROM alpine:3.23
RUN apk add --no-cache zig=0.15.2-r0
WORKDIR /app
CMD sleep infinity