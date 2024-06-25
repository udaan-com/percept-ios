
#!/bin/bash

# ./scripts/prepare-release.sh <new version>
# eg ./scripts/prepare-release.sh "1.0.0"

set -eux

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <new_version>"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="$1"

# bump version
./scripts/bump-version.sh $NEW_VERSION

# commit changes
./scripts/commit-code.sh

# create and push tag
./scripts/create-tag.sh $NEW_VERSION
