
1. Run the script with the tag name; it will update the version file and create a new tag.

    ```bash
    ./scripts/prepare-release.sh 1.0.0
    ```

 2. Go to [GH Releases](https://github.com/udaan-com/percept-ios)
 3. Choose a release name (e.g. `1.0.0`), and the tag you just created, ideally the same.
 4. Write a description of the release.
 5. Publish the release.
 6. SPM will be managed with git version. Publish Cocoapods
    1. pod lib lint Percept.podspec
    2. https://guides.cocoapods.org/making/getting-setup-with-trunk.html
        a) pod trunk register your.email@example.com 'Your Name' --description='Personal Laptop' // first time publish
        b) ask someone to add you as a maintainer
    3. pod trunk push Percept.podspec

 7. Done.
