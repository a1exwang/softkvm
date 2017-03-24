#!/bin/bash

# e.g. ./client.sh 192.168.233.1 8223
if [ $# -ne 2 ]; then
  echo "USAGE: sudo ./client.sh SERVER_IP SERVER_PORT"
  exit 1
fi
if [ $(id -u) -ne 0 ]; then
  echo "You must run as root"
  exit 1
fi
SERVER=$1
PORT=$2
nc $SERVER $PORT | ./vinput awvkb0 &
nc $SERVER $(expr $PORT + 2) | ./vinput awvmice0 &


wait
