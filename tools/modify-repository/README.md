# modify-repository

This is a simple script, that can create PRs or push on a repository without actually cloning the files.
Adobe uses this tool to automate any commits and pull requests to its internal components.

## Usage 

    usage: modify.py [-h] [-g GITHUB_INSTANCE] -r REPOSITORY -b BRANCH -f FILES -m
                    MESSAGE [-i] [-p PULL_REQUEST_MESSAGE]
                    [-t TARGET_BRANCH_PREFIX] [-n] [-w] [--no-pr]
                    [--commit-empty] [--allow-duplicates]
                    [--append-pr-to-file APPEND_PR_TO_FILE]
                    [command [command ...]]

    positional arguments:
    command               command to execute to update files with optional
                            parameters, e.g. "vim"

    optional arguments:
    -h, --help            show this help message and exit
    -g GITHUB_INSTANCE, --github-instance GITHUB_INSTANCE
                            The github instance, defaults to https://github.com/
    -r REPOSITORY, --repository REPOSITORY
                            repository name, e.g. adobe/sledgehammer-registry
    -b BRANCH, --branch BRANCH
                            base branch, e.g. master
    -f FILES, --file FILES
                            files to edit, e.g. tools/git/VERSION; might be used
                            multiple times
    -m MESSAGE, --message MESSAGE
                            Commit message
    -i, --ignore-missing  to create new files, set this flag
    -p PULL_REQUEST_MESSAGE, --pull-request-message PULL_REQUEST_MESSAGE
                            Pull request message, e.g. @someone please review,
                            merge and delete branch
    -t TARGET_BRANCH_PREFIX, --target-branch-prefix TARGET_BRANCH_PREFIX
                            name of the target branch prefix, e.g. feature/fixed-
                            thing
    -n, --no-dry-run      If set actually create a pull request and not just do
                            a dry-run
    -w, --ignore-whitespace-only-changes
                            When this flag is set, no commit or pr will be created
                            for whitespace only changes
    --no-pr               Do not create a pull request, instead create commit
                            directly on the base branch
    --commit-empty        Commit even if nothing changed
    --allow-duplicates    If false will only create a PR if it does not exist
                            yet
    --append-pr-to-file APPEND_PR_TO_FILE
                            Appends link of the created pull request to a file.

## Example

    $ modify-repository -r adobe/sledgehammer-registry -b master -f tools/git/VERSION -m "TEST" --pull-request-message "This is a test" --target-branch-prefix "test" -- bash -c "echo '1.0.0' > tools/git/VERSION"

## Contributors

* Florian Noeding 
* Nils Plaschke 
* Leandro Baltazar
* Jed Glazner
* Malthe Husmann
* Thorsten Schaefer