
 1. Choose a tag name (e.g. `1.0.0`), this is the version number of the release.
    1. Run the script with the tag name; it will update the version file and create a new tag.

    ```bash
    ./scripts/prepare-release.sh 1.0.0
    ```

 3. Go to [GH Releases](https://github.com/udaan-com/percept-ios)
 4. Choose a release name (e.g. `1.0.0`), and the tag you just created, ideally the same.
 5. Write a description of the release.
 6. Publish the release.
 7. Publish Cocoapods
 8. Done.
