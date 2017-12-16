#!/bin/bash
set -eo pipefail
docker build -t haproxy:conjur .
