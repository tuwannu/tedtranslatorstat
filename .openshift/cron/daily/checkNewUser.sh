#!/bin/bash

cd ${OPENSHIFT_REPO_DIR}; rails runner -e production checkNewUser.rb