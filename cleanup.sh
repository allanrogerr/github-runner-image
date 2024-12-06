#!/bin/bash

docker system prune --volumes --force
# Clear kind
kind delete cluster
# Clear go
go clean -cache
go clean -modcache

