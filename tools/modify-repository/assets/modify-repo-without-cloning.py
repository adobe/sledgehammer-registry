#!/usr/bin/env python

# Copyright 2018 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe. 
# 
# Contributors: 
#       Florian Noeding 
#       Nils Plaschke 
#       Leandro Baltazar
#       Jed Glazner
#       Malthe Husmann
#       Thorsten Schaefer

from __future__ import print_function

import os
from datetime import datetime
import tempfile
import os.path
import argparse
import shutil
import sys
import subprocess
import difflib
import hashlib
import json

# install via "pip install github3.py" or similar
import github3


def main():
    args = parse_args()

    token = os.getenv('GITHUB_ACCESS_TOKEN')
    if not token:
        print('Please set the environment variable GITHUB_ACCESS_TOKEN to your git.corp token')
        sys.exit(1)
    
    if args.github_instance is None:
        gh = github3.login(token=token)
    else:
        gh = github3.enterprise_login(token=token, url=args.github_instance)

    user = gh.me()
    args.username = user.name
    args.email = user.email

    if args.username is None:
        print('Please set the username in your github profile to use this tool')
        sys.exit(1)

    if args.email is None:
        args.email = "unkown@unkown.com"

    if not args.no_dry_run:
        print("---\nDRY RUN ACTIVE! NO PUSH WILL BE DONE\n---")

    print('Repo: {}'.format(args.repository))
    print('Command: {}'.format(args.command))
    print('Changes will be commited as: {} <{}>'.format(args.username, args.email))
    print('---')

    # get repo
    repo_org, repo_name = args.repository.split('/', 1)
    repo = gh.repository(repo_org, repo_name)

    # make temporary directory and fetch files, let user edit them
    temp_dir = tempfile.mkdtemp()
    def get_target_path(fn):
        return os.path.join(temp_dir, fn)

    try:
        before = fetch_files(repo, args.branch, get_target_path, args.files, args.ignore_missing)
        after = update_files(args.command, get_target_path, args.files, args)

        # change hash
        hash = hashlib.md5(json.dumps(after, sort_keys=True).encode('utf-8')).hexdigest()

        # get a branch with the change hash
        branch_name = "{}-{}".format(args.target_branch_prefix, hash)
        try:
            existing_branch = repo.branch(branch_name)
        except github3.exceptions.NotFoundError as e:
            existing_branch = None

        print("The hash of the changes are: {}".format(hash))

        display_diff(before, after)

        has_changes = args.commit_empty
        for fn in args.files:
            if before[fn] == after[fn]:
                continue
            if after[fn] is None:
                has_changes = True
                break

            if args.ignore_whitespace_only_changes:
                if not has_whitespace_only_changes(before[fn], after[fn]):
                    has_changes = True
                    break
            else:
                has_changes = True
                break

        if has_changes and args.no_dry_run:
            tree_data, deleted_files = compute_changes(repo, get_target_path, args.files)
            commit = create_commit(repo, args.branch, tree_data, args.message, args.username, args.email)

            if args.no_pr:
                update_head_to_new_commit(repo, args.branch, commit)
                branch_name = args.branch
            elif args.allow_duplicates and existing_branch is not None:
                # There is already a branch with the same name, so use the time
                branch_name = '{}-{}'.format(args.branch, datetime.now().strftime('%Y%m%d%H%M%S'))
                create_branch(repo, branch_name, commit)
            elif not args.allow_duplicates and existing_branch is not None:
                error_message =  "There is already a branch '{}'.\nAssuming there is a PR using this branch... Aborting".format(branch_name)
                raise RuntimeError(error_message)
            else:
                create_branch(repo, branch_name, commit)

            # slightly hacky way to delete files: calculating a tree in create_commit with removed files is non-trivial. do it in separate commits here
            for fn in deleted_files:
                file_content = repo.contents(fn, branch_name)
                if file_content is not None:
                    repo.delete_file(
                        fn,
                        'removed file {}'.format(fn),
                        file_content.sha,
                        branch_name,
                        {'name': args.username, 'email': args.email},
                        {'name': args.username, 'email': args.email}
                    )

            if not args.no_pr:
                pr_link = create_pull_request(repo, args.branch, branch_name, args.message, args.pull_request_message)
                print(pr_link)
                if args.append_pr_to_file is not None:
                    with open(args.append_pr_to_file, "a") as prlogfile:
                        prlogfile.write(pr_link + "\n")
        elif has_changes and not args.no_dry_run:
            print("---\nDRY RUN ACTIVE! NO PUSH WILL BE DONE\n---")

    finally:
        # cleanup
        shutil.rmtree(temp_dir, ignore_errors=True)



def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('-g', '--github-instance', required=False, default=None, help='The github instance, defaults to https://github.com/')
    parser.add_argument('-r', '--repository', required=True, help='repository name, e.g. adobe/sledgehammer-registry')
    parser.add_argument('-b', '--branch', required=True, help='base branch, e.g. master')
    parser.add_argument('-f', '--file', required=True, action='append', dest='files', help='files to edit, e.g. tools/git/VERSION; might be used multiple times')
    parser.add_argument('-m', '--message', required=True, help='Commit message')
    parser.add_argument('-i', '--ignore-missing', action='store_true', required=False, help='to create new files, set this flag')
    parser.add_argument('-p', '--pull-request-message', required=False, help='Pull request message, e.g. @someone please review, merge and delete branch')
    parser.add_argument('-t', '--target-branch-prefix', required=False, help='name of the target branch prefix, e.g. feature/fixed-thing')
    parser.add_argument('-n', '--no-dry-run', action='store_true', required=False, help='If set actually create a pull request and not just do a dry-run')
    parser.add_argument('-w', '--ignore-whitespace-only-changes', action='store_true', required=False, help='When this flag is set, no commit or pr will be created for whitespace only changes')
    parser.add_argument('--no-pr', action='store_true', required=False, help='Do not create a pull request, instead create commit directly on the base branch')
    parser.add_argument('--commit-empty', action='store_true', required=False, help='Commit even if nothing changed')
    parser.add_argument('--allow-duplicates', action='store_true', required=False, help='If false will only create a PR if it does not exist yet')
    parser.add_argument('--append-pr-to-file', required=False, help='Appends link of the created pull request to a file.')

    parser.add_argument('command', nargs='*', help='command to execute to update files with optional parameters, e.g. "vim"')
    
    args = parser.parse_args()
    if not args.command:
        parser.error('command to update files is missing')

    if not args.no_pr:
        if not args.pull_request_message:
            parser.error('need --pull-request-message')
        if not args.target_branch_prefix:
            parser.error('need --target-branch-prefix')

    return args


def fetch_files(repo, ref, get_target_path, filenames, ignore_missing):
    before = {}

    for fn in filenames:
        contents = repo.file_contents(fn, ref=ref)
        if contents is None:
            if ignore_missing:
                real_contents = ''
            else:
                raise RuntimeError('Failed to fetch file {}.'.format(fn))
        else:
            real_contents = contents.decoded.decode('utf-8') # this is still utf-8 encoded, even though it's called decoded

        before[fn] = real_contents

        target = get_target_path(fn)
        target_dir = os.path.dirname(target)
        if not os.path.exists(target_dir):
            os.makedirs(os.path.dirname(target))

        with open(target, 'w') as f:
            f.write(real_contents)

    return before


def update_files(command, get_target_path, filenames, args):
    cmd = []
    cmd.extend(command)
    cmd.extend(filenames)

    proc = subprocess.Popen(
        cmd,
        shell=False,
        cwd=get_target_path(''),
        close_fds=True,
    )

    returncode = proc.wait()

    if returncode != 0:
        raise RuntimeError('{} returned an error'.format(command))

    after = {}
    for fn in filenames:
        if os.path.exists(get_target_path(fn)):
            with open(get_target_path(fn)) as f:
                after[fn] = f.read()
        else:
            after[fn] = None

    return after


def display_diff(before, after):
    for fn in before:
        before_lines = before[fn].splitlines()
        if after[fn] is None:
            after_lines = ''
        else:
            after_lines = after[fn].splitlines()
        for diff_line in difflib.unified_diff(before_lines, after_lines, 'orig/{}'.format(fn), 'new/{}'.format(fn), lineterm=''):
            print(diff_line)


def has_whitespace_only_changes(a, b):
    for char in ('\n', '\r', ' ', '\t'):
        a = a.replace(char, '')
        b = b.replace(char, '')

    return a == b


def compute_changes(repo, get_target_path, filenames):
    tree_data = []
    deleted = []
    for fn in filenames:
        if not os.path.exists(get_target_path(fn)):
            deleted.append(fn)
        else:
            with open(get_target_path(fn)) as f:
                contents = f.read()

            blob = repo.create_blob(contents, encoding='utf-8')
            entry = {}
            entry['path'] = fn
            entry['mode'] = '100644'
            entry['type'] = 'blob'
            entry['sha'] = blob
            tree_data.append(entry)

    return tree_data, deleted


def create_commit(repo, base_branch, tree_data, commit_message, username, email):
    # get base tree info
    base_branch = repo.branch(base_branch)
    base_tree_sha = base_branch.commit.commit.tree.sha

    # create new tree
    if tree_data:
        tree = repo.create_tree(tree_data, base_tree_sha)
        new_sha = tree.sha
    else:
        # if there are no changes, still files might have been removed
        # it's easier to create an empty commit to simplify the remaining workflow here
        new_sha = base_tree_sha

    # actually commit this
    commit = repo.create_commit(commit_message,
                                new_sha,
                                [base_branch.commit.sha],
                                {'name': username, 'email': email},
                                {'name': username, 'email': email},
    )

    return commit


def create_branch(repo, branch_name, commit):
    # create branch entry for this commit
    ref = repo.create_ref('refs/heads/{}'.format(branch_name), commit.sha)

    return branch_name


def create_pull_request(repo, base_branch, branch_name, title, pull_request_message):
    # create pull request
    pull = repo.create_pull(title,
                     base_branch,
                     branch_name,
                     pull_request_message,
    )
    return pull.html_url


def update_head_to_new_commit(repo, branch, commit):
    ref = repo.ref('heads/{}'.format(branch))
    ref.update(commit.sha)


if __name__ == '__main__':
    main()
