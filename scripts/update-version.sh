
#!/bin/bash

# ./scripts/bump-version.sh <new version>
# eg ./scripts/bump-version.sh "1.0.0"

set -eux

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <new_version>"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

NEW_VERSION="$1"

# Replace `postHogVersion` with the given version
perl -pi -e "s/perceptSdkVersion = \".*\"/perceptSdkVersion = \"$NEW_VERSION\"/" Sources/percept-ios/internal/Version.swift
echo "Updated perceptSdkVersion to '$NEW_VERSION' in Version.swift"

# Replace `s.version` with the given version
perl -pi -e "s/s\.version          = \".*\"/s\.version          = \"$NEW_VERSION\"/" Percept.podspec
echo "Updated s.version to '$NEW_VERSION' in $PODSPEC_FILE"
