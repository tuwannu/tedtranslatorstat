#!/bin/bash

timeout 1000 ${OPENSHIFT_REPO_DIR}script/rails runner "${OPENSHIFT_REPO_DIR}dailyExtractToDb.rb"