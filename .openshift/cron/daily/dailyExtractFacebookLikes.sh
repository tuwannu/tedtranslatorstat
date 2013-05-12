#!/bin/bash

source ~/app-root/data/.bash_profile

cd ${OPENSHIFT_REPO_DIR}; rails runner -e production dailyExtractFacebookLikes.rb