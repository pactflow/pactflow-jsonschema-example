#!/bin/bash

# NOTE: don't copy me in real life - we never want to ignore build failures!
set +e

make ci_consumer # first run should fail
RESULT=$?
make ci_provider # second run should pass!

if [ $RESULT != 0 ]; then
  make ci_consumer # third run should pass on second go
fi