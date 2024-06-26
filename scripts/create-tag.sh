
#!/bin/bash

# ./scripts/create-tag.sh <new version>
# eg ./scripts/create-tag.sh "1.0.0"

set -eux


# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <new_version>"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="$1"

git tag -a ${NEW_VERSION} -m "${NEW_VERSION}"
git push && git push --tags
