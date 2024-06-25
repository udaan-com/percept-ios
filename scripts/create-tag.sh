
#!/bin/bash

# ./scripts/create-tag.sh <new version>
# eg ./scripts/create-tag.sh "1.0.0"

set -eux

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="$1"

git tag -a ${NEW_VERSION} -m "${NEW_VERSION}"
git push && git push --tags
