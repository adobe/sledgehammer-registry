#!/usr/bin/env bash
set -e

# Stuff you can edit...

# The registry where the tools will be pushed to if a release is ongoing
REGISTRY=''
# The repository where the tools will be pushed to if a release is ongoing
REPOSITORY='sledgehammers'
# With the following:
# REGISTRY='docker.io'
# REPOSITORY='tools'
# a resulting tool `git` in version `0.1.0` will be named like this
# docker.io/tools/git:latest and
# docker.io/tools/git:0.1.0

# If enabled will push a tag for each relased tool to git
# A tool `git` in version `0.1.0` will be released with the following tag in git: git-0.1.0
PUSH_TAGS="true"

# If enabled all released tools will be pushed to the given registry and repository mentioned above.
# This can be disabled if docer automated builds are enabled.
# In that case PUSH_TAGS should be set to "true" so that tags are pushed and docker can distinguish the tools
PUSH_TOOLS="false"

# You need to define the folder of the tools again... yeah, I know...
TOOLS_FOLDER='tools'

# Stuff you shouldn't edit anymore

# Define some colors that we can use in the script
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# gets the current branch, will be used to detect any changes
CURRENT_BRANCH=${TRAVIS_PULL_REQUEST_BRANCH:-${TRAVIS_BRANCH:-"$(git rev-parse --abbrev-ref HEAD | tr -d '[:space:]')"}}
CURRENT_COMMIT="$(git rev-parse HEAD | tr -d '[:space:]')"

# This is the tool that is currently handled
TOOL_NAME=""

# Return the earliest common ancestor of master and the given branch.
function get_common_ancestor {
  git merge-base "${CURRENT_COMMIT}" origin/master | tr -d '[:space:]'
}

# Returns all changed files for the current branch
# If there are local changes, add them. If empty:
# If we are on master, it will take the files from the current commit
# If we are on a branch it will take all files on that branch
function get_changed_files {
    # get local changes
    local_changes=$(git status -s | wc -l | tr -d '[:space:]')
    if [ "${local_changes}" -ne 0 ]; then
        git status -s
    fi
    # if on master or on a merge commit then take changes from the current HEAD
    if on_master || is_merge_commit; then
        git log -m -1 --name-only --pretty="format:" "${CURRENT_COMMIT}"
    else
        # not on master, so get common ancestor and take files 
        ancestor=$(get_common_ancestor)
        git diff --name-only "${ancestor}" "${CURRENT_COMMIT}"
    fi
}

# Will return true if the current commit is a merge commit
function is_merge_commit {
    if [ "$(git rev-list --min-parents=2 --max-count=1 HEAD)" = "$(git rev-parse HEAD)" ]; then
        return 0
    else
        return 1
    fi
}

# Will detect if we are on the master branch
function on_master {
    if [ "${CURRENT_BRANCH}" = "master" ]; then
        return 0
    fi
    return 1
}

# A tool can be a regular tool with all needed files or just a tool.json referencing an external tool
# If there is only a tool.json, then consider this tool not changed so that all steps can be skipped
function check_if_valid_tool {
    # check amount of files
    # shellcheck disable=SC2012
    if [ "$(ls -1q ${TOOLS_FOLDER}/${TOOL_NAME} | wc -l | tr -d '[:space:]')" = "1" ] && [ -f "${TOOLS_FOLDER}/${TOOL_NAME}/tool.json" ]; then
        exit 0
    fi
}

# Will get the current version of the tool and trims it at the first `-`
function get_tool_version {
    sed -e 's;-[^-]*$;;' < "${TOOLS_FOLDER}/${TOOL_NAME}/VERSION"
}

# Will return the image name of the current tool
function get_image_name {
    if [ -z "${DOCKER_REPO}" ]; then
        if [ "${REGISTRY}" = "" ]; then
            echo "${REPOSITORY}/${TOOL_NAME}"
        else
            echo "${REGISTRY}/${REPOSITORY}/${TOOL_NAME}"
        fi
    else
        echo "${DOCKER_REPO}"
    fi
}

# Will push a tag on the current commit
function push_tag {
    if [ "${PUSH_TAGS}" = "true" ]; then
        # shellcheck disable=SC2002
        TAG="${TOOL_NAME}-${RAW_VERSION}"
        echo "Pushing tag '${TAG}'"
        git tag -f "${TAG}"
        git push "https://${GITHUB_ACCESS_TOKEN}:x-oauth-basic@github.com/adobe/sledgehammer-registry.git" --tags -f
        echo -e "........[${GREEN}PASS${NC}]"
    fi
}

# Will push the tool container to docker
function push_tool {
    if [ "${PUSH_TOOLS}" = "true" ]; then
        IMAGEID=$(docker images -q "$(get_image_name):latest")
        docker tag "${IMAGEID}" "$(get_image_name):${RAW_VERSION}"
        docker tag "${IMAGEID}" "$(get_image_name):latest"
        echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USER" --password-stdin
        docker push "$(get_image_name)"
        echo "Pushed '${TOOL_NAME}' as '$(get_image_name):${RAW_VERSION}'"
        echo -e "........[${GREEN}PASS${NC}]"
    fi
}

# Will tag the image and push them if the tool has changed
function release {
    if has_changed;
    then
        echo "Releasing..."
        push_tool
        push_tag
        echo -e "........[${GREEN}PASS${NC}]"
    fi
}

# Will verify certain aspects of the tool
# * Will inspect the tool container with an image policy image
# * Will verify the tool has a README.md
# * Will verify the tool has a VERSION
# * Will verify the tool has a Dockerfile
# * Will verify the tool passes the version test
function verify {
    if has_changed;
    then
        echo "Verifying..."
        IMAGEID=$(docker images -q "$(get_image_name):latest")
        if [ "${IMAGEID}" != "" ]
        then
            docker inspect "${IMAGEID}" | docker run --rm -i bryanlatten/docker-image-policy:latest
        else
            echo "Image '${TOOL_NAME}' not found, aborting"
            echo -e "........[${RED}FAIL${NC}]"
            exit 127
        fi

        test -f "${TOOLS_FOLDER}/${TOOL_NAME}/README.md" || \
          { echo "${TOOL_NAME}: There is no README.md file"; echo -e "........[${RED}FAIL${NC}]"; exit 1; }

        test -f "${TOOLS_FOLDER}/${TOOL_NAME}/VERSION" || \
          { echo "${TOOL_NAME}: There is no VERSION file"; echo -e "........[${RED}FAIL${NC}]"; exit 1; }

        test -f "${TOOLS_FOLDER}/${TOOL_NAME}/Dockerfile" || \
          { echo "${TOOL_NAME}: There is no Dockerfile"; echo -e "........[${RED}FAIL${NC}]"; exit 1; }

        test -f "${TOOLS_FOLDER}/${TOOL_NAME}/tool.json" || \
          { echo "${TOOL_NAME}: There is no tool.json"; echo -e "........[${RED}FAIL${NC}]"; exit 1; }

        verify_tool_version "$TOOL_NAME" || \
          { echo "$TOOL_NAME: Failed version test"; echo -e "........[${RED}FAIL${NC}]"; exit 1; }
    fi
}

# Will loop over each tool an check if there is an update for the version if so, it will create a PR with the new version
function update {

    if [[ -f "./${TOOLS_FOLDER}/${TOOL_NAME}/check_update.sh" ]]; then
        echo "Checking for a new version..."
        OLD_VERSION=$(get_tool_version)
        cd "${TOOLS_FOLDER}/${TOOL_NAME}"
        NEW_VERSION=$("./check_update.sh" | tr -d '[:space:]')

        if [ "${NEW_VERSION}" != "${OLD_VERSION}" ]; then
            # assume a new version is found
            echo "Found new version '${NEW_VERSION}', updating from '${OLD_VERSION}'"
            modify-repository -r adobe/sledgehammer-registry -b master -f "${TOOLS_FOLDER}/${TOOL_NAME}/VERSION" -m "Updated \`${TOOL_NAME}\` from \`${OLD_VERSION}\` to \`${NEW_VERSION}\`" --pull-request-message "* Updated \`${TOOL_NAME}\` from \`${OLD_VERSION}\` to \`${NEW_VERSION}\`" --target-branch-prefix "update-`${TOOL_NAME}`" --no-dry-run -- bash -c "echo '${NEW_VERSION}-1' > ${TOOLS_FOLDER}/${TOOL_NAME}/VERSION"
        fi
        # modify repo...
        echo -e "........[${GREEN}PASS${NC}]"
    fi
}

# Will verify that the tool returns the correct version
function verify_tool_version {
    echo "Testing version..."

    TOOL_VERSION=""

    EXPECTED_TOOL_VERSION=$(get_tool_version)

    cd "${TOOLS_FOLDER}/${TOOL_NAME}"
    if [[ -f "./test_version.sh" ]]; then
        echo "Executing custom version test..."
        TOOL_VERSION=$("./test_version.sh" "$(get_image_name)" | tr -d '[:space:]')
    else
        TOOL_VERSION="$(docker run --rm -it "$(get_image_name)" --version | tr -d '[:space:]')"
    fi

    if [[ "$TOOL_VERSION" != "$EXPECTED_TOOL_VERSION" ]]; then
        echo "Expected version '$EXPECTED_TOOL_VERSION', but got '$TOOL_VERSION'"
        echo -e "........[${RED}FAIL${NC}]"
        return 1
    fi
    echo -e "........[${GREEN}PASS${NC}]"
    return 0
}

# Will clean old tool images
function clean {
    if has_changed;
    then
        IMAGEID=$(docker images -q "(get_image_name)")
        if [ "${IMAGEID}" != "" ]
        then
            echo "Cleaning..."
            docker rmi -f "${IMAGEID}" || true
            echo -e "........[${GREEN}PASS${NC}]"
        fi
    fi
}

# Will build the tool
function build {
    if has_changed;
    then
        
        VERSION=$(get_tool_version) # Must be prior to CWD change.

        echo "Building..."
        cd "${TOOLS_FOLDER}/${TOOL_NAME}"
        
        if [[ -d "../../helpers" ]]; then
            cp -r ../../helpers ./assets
        fi

        DOCKER_BUILD_ARGS="--build-arg VERSION=${VERSION}"
        if [[ -f "./pre-build.sh" ]]; then
          echo "Executing pre-build script..."
          # shellcheck disable=SC1091
           trap ". ./post-build.sh && exit 1" EXIT # ensure cleanup, if pre-build.sh fails
           # shellcheck disable=SC1091
           . "./pre-build.sh"
           echo -e "........[${GREEN}PASS${NC}]"
           trap - EXIT
        fi

        # We need to disable the shell failing automatically after a docker build fail.
        # If we do, we do not run post-build.sh and therefore no cleanup is done
        set +e
        # shellcheck disable=SC2086
        docker build -t "$(get_image_name):latest" -t "$(get_image_name):${RAW_VERSION}" --rm=true ${DOCKER_BUILD_ARGS} .

        DOCKER_BUILD_STATUS=$?
        set -e # re-enable exit on non-zero status

        if [ "${DOCKER_BUILD_STATUS}" -ne 0 ]; then
            echo -e "........[${RED}FAIL${NC}]"
        else
            echo -e "........[${GREEN}PASS${NC}]"
        fi

        if [[ -f "./post-build.sh" ]]; then
          echo "Executing post-build script..."
          # shellcheck disable=SC1091
          . ./post-build.sh
          echo -e "........[${GREEN}PASS${NC}]"
        fi
        rm -Rf ./assets/helpers
        exit "${DOCKER_BUILD_STATUS}"
    fi
}

# Will try to detect if the tool has changed
function has_changed {
    TOOL_ONLY=$1
    # Consider the tool changed, if there are local changes not committed yet
    if git status -s | grep "${TOOLS_FOLDER}/${TOOL_NAME}" > /dev/null; then
    #   echo "Local changes (not committed) detected..."
      return 0
    fi

    # If the PRB is running (aka the current branch is not
    # master) then also consider changes to the build infrastructure, i.e. in
    # that case all tools are considered changed. 
    if on_master || [ ! -z "${TOOL_ONLY}" ]; then
        FILES=$(echo "${CHANGED_FILES}" | grep -e "${TOOLS_FOLDER}/${TOOL_NAME}")
    else
        FILES=$(echo "${CHANGED_FILES}" | grep -e "${TOOLS_FOLDER}/${TOOL_NAME}" -e ".travis.yml" -e "make.sh" -e "Makefile" -e "helpers/")
    fi
    
    if [ -n "${FILES}" ]; then
        return 0
    else
        return 1
    fi
}

# Check the given tool for different aspects:
# * If the tool was changed:
#   * Run static code analysis for bash scripts using shellcheck.
# * If the tool has changed and we're on master (aka during the CI build):
#   * Verify no container with the given version exists in the repository.
function check {
    if has_changed; then
        FILES=$(find "${TOOLS_FOLDER}/${TOOL_NAME}" -type f -name '*.sh' -o -name 'execute')
        if [[ -n "${FILES}" ]]; then
            echo "Testing shell scripts..."
            # shellcheck disable=SC2086
            shellcheck -a ${FILES}
            echo -e "........[${GREEN}PASS${NC}]"

            if on_master || has_changed "true"; then
                echo "Testing if image already exists..."
                if docker pull "$(get_image_name):${RAW_VERSION}" &>/dev/null; then
                    echo -e "........[${RED}FAIL${NC}]"
                    echo "Tool has been changed, but the version seems to be the same"
                    echo "Please increase the version in '${TOOLS_FOLDER}/${TOOL_NAME}/VERSION' for this PRB to succeed."
                    exit 1
                else
                    echo -e "........[${GREEN}PASS${NC}]"
                fi
            fi
        fi
    fi
}

# prefix all output with the name of the tool
exec > >(sed "s/^/[${2}]: /")
exec 2> >(sed "s/^/[${2}]: (stderr) /" >&2)

CHANGED_FILES=$(get_changed_files)
TOOL_NAME="${2}"

check_if_valid_tool

RAW_VERSION=$(cat "./${TOOLS_FOLDER}/${TOOL_NAME}/VERSION" | tr -d '[:space:]')

case "$1" in
    clean)
            clean
            ;;
    build)
            build
            ;;
    verify)
            verify
            ;;
    release)
            release
            ;;
    check)
            check
            ;;
    update)
            update
            ;;
        *)
            echo "Usage: $0 {build|clean|verify|release|check} <tool_name>"
            exit 1
esac
