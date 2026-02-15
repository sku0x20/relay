# Todo List

- handle SIGPIPE
  - set MSG_NOSIGNAL on write/send.
    - close connection on EPIPE
    - https://man.freebsd.org/cgi/man.cgi?query=socket&apropos=0&sektion=2&manpath=FreeBSD+15.0-RELEASE+and+Ports&format=html
    - https://man7.org/linux/man-pages/man7/socket.7.html
- enable keepalive
- handle graceful shutdown

- backpressure
  - adjusting the backpressure in listen
    - can stop accepting new connections if overloaded
  - outbound pressure; slow client read
    - drop if write() returns EAGAIN (socket send buffer full)
  - inbound pressure; fast client write
    - client sending data faster than server can process
    - Limit input buffer growth
    - drop if it reached that limit