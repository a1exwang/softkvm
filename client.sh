#!/bin/bash

# e.g. ./client.sh 192.168.233.1 8223
SERVER=$1
PORT=$2
nc $SERVER $PORT | ./vinput awvkb0 &
nc $SERVER $(expr $PORT + 2) | ./vinput awvmice0 &


wait
