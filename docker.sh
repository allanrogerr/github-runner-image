#!/bin/bash
if [ "\$1" == "build" ]; then
  shift
  args=( "\$@" )
  /usr/bin/_docker build --network=host "\${args[@]}"
else
  args=( "\$@" )
  /usr/bin/_docker "\${args[@]}"
fi