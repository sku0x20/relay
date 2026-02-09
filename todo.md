# Todo List

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