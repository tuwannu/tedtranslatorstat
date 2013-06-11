#!/bin/bash

source /usr/bin/rhcsh
source ~/app-root/data/.bash_profile

cd ${OPENSHIFT_REPO_DIR}; nohup rails runner -e production dailyExtractFacebookLikes.rb >/dev/null 2>&1 &
