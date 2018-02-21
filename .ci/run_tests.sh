#!/usr/bin/env bash
set -e

export BUSTED_ARGS="-o gtest -v --exclude-tags=flaky,ipv6"
export TEST_CMD="bin/busted $BUSTED_ARGS --exclude-tags=`[[ "$KONG_TEST_DATABASE" = cassandra ]] && echo postgres || echo cassandra`"

if [[ "$KONG_TEST_DATABASE" = postgres ]]; then
  if [[ "$TEST_SUITE" != "unit" ]] && [[ "$TEST_SUITE" != "lint" ]]; then
    createuser --createdb kong
    createdb -U kong kong_tests
  fi
fi

if [ "$TEST_SUITE" == "lint" ]; then
    make lint
elif [ "$TEST_SUITE" == "unit" ]; then
    make test
elif [ "$TEST_SUITE" == "integration" ]; then
    make test-integration
elif [ "$TEST_SUITE" == "plugins" ]; then
    make test-plugins
fi
