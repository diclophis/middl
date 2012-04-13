#!/usr/bin/env ruby

worker_processes 2
rewindable_input false

Rainbows! do
  use :FiberSpawn
  keepalive_timeout 0
  worker_connections 2
  client_max_body_size 11*1024*1024 # 5 megabytes
end
