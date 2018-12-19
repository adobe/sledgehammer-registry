# modify-repository

This is a simple script, that can create PRs or push on a repository without actually cloning the files.

## Example

    $ modify-repository -r adobe/sledgehammer-registry -b master -f tools/git/VERSION -m "TEST" --pull-request-message "This is a test" --target-branch-prefix "test" -- bash -c "echo '1.0.0' > tools/git/VERSION"