FROM alpine:3.23
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community zig=0.16.0-r1
WORKDIR /app
CMD sleep infinity