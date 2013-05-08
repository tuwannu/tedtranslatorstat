#!/bin/bash

source ~/app-root/data/.bash_profile

cd ${OPENSHIFT_REPO_DIR}; timeout 2000 rails runner -e production dailyExtractFacebookLikes.rb