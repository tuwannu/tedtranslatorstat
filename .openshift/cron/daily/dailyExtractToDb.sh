#!/bin/bash

nohup ${OPENSHIFT_REPO_DIR}script/rails runner "${OPENSHIFT_REPO_DIR}dailyExtractToDb.rb" >/dev/null 2>&1 &
