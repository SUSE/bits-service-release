#!/bin/bash -e

cd $(dirname $0)/../../

bosh -u x -p x target $BOSH_TARGET Lite
bosh login $BOSH_USERNAME $BOSH_PASSWORD
bosh status

./scripts/generate-bosh-lite-manifest
rm -rf ../assets/*

mv deployments/bits-service-release-bosh-lite.yml ../assets/manifest.yml
cat ../assets/manifest.yml

version=$(cat $VERSION_FILE)
bosh create release --force --name bits-service --with-tarball --version $version
mv dev_releases/bits-service/bits-service-*.tgz ../assets/
