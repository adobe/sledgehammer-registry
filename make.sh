#!/usr/bin/env bash
set -e

SUITE_NAME='sledgehammers'
TOOLS_FOLDER='tools'
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

function release {
    TOOL_NAME=$1
    if has_changed "${TOOL_NAME}";
    then
        VERSION=$(cat "${TOOLS_FOLDER}/${TOOL_NAME}/VERSION")
        IMAGEID=$(docker images -q "${SUITE_NAME}/${TOOL_NAME}:latest")
        docker tag "${IMAGEID}" "${SUITE_NAME}/${TOOL_NAME}:${VERSION}"
        docker push "${SUITE_NAME}/${TOOL_NAME}"
    else
        echo "Image '${TOOL_NAME}' has not changed, no push will be done"
    fi
}

function verify {
    TOOL_NAME=$1
    if has_changed "${TOOL_NAME}";
    then
        echo "Verifying tool '${SUITE_NAME}/${TOOL_NAME}'"
        IMAGEID=$(docker images -q "${SUITE_NAME}/${TOOL_NAME}:latest")
        if [ "${IMAGEID}" != "" ]
        then
            echo "Testing ${TOOL_NAME}"
            docker inspect "${IMAGEID}" | docker run --rm -i bryanlatten/docker-image-policy:latest
        else
            echo "Image '${TOOL_NAME}' not found, aborting"
            exit 127
        fi

        test -f "tools/${TOOL_NAME}/README.md" || \
          { echo "${TOOL_NAME}: There is no README.md file"; exit 1; }

        test -f "tools/${TOOL_NAME}/VERSION" || \
          { echo "${TOOL_NAME}: There is no VERSION file"; exit 1; }

        test -f "tools/${TOOL_NAME}/Dockerfile" || \
          { echo "${TOOL_NAME}: There is no Dockerfile"; exit 1; }

        # grep -iq "^ENTRYPOINT" "tools/${TOOL_NAME}/Dockerfile" || \
        #   { echo "${TOOL_NAME}: No entrypoint defined in Dockerfile"; exit 1; }

        verify_tool_version "$TOOL_NAME" || \
          { echo "$TOOL_NAME: Failed version test"; exit 1; }

    else
        echo "Image '${TOOL_NAME}' has not changed, nothing to verify"
    fi
}

function verify_tool_version {
    TOOL_NAME="$1"

    tmppath=$(mktemp -d)
    trap 'rm -rf $tmppath' RETURN
    export PATH="$tmppath:$PATH"
    export SLH_SKIP_UPDATE="true"

    # Just make sure there is no version set for the tool under test
    # shellcheck disable=SC2046
    unset $(echo "SLH_${TOOL_NAME}" | awk '{ gsub("-", "_", $0); print toupper($0) "_VERSION" }')

    echo "Testing version of $TOOL_NAME"

    TOOL_VERSION=""
    EXPECTED_TOOL_VERSION=$(get_tool_version "$TOOL_NAME")
    if [[ -f "tools/$TOOL_NAME/test_version.sh" ]]; then
        TOOL_VERSION=$("tools/$TOOL_NAME/test_version.sh" | tr -d '[:space:]')
    else
        TOOL_VERSION="$(docker run --rm -it ${SUITE_NAME}/${TOOL_NAME} $TOOL_NAME --version | tr -d '[:space:]')"
    fi

    if [[ "$TOOL_VERSION" != "$EXPECTED_TOOL_VERSION" ]]; then
        echo "Expected version '$EXPECTED_TOOL_VERSION', but got '$TOOL_VERSION'"
        return 1
    fi
    echo "PASS"
    return 0
}

function clean {
    TOOL_NAME=$1
    if has_changed "${TOOL_NAME}";
    then
        IMAGEID=$(docker images -q "${SUITE_NAME}/${TOOL_NAME}")
        if [ "${IMAGEID}" != "" ]
        then
            echo "Cleaning image '${TOOL_NAME}'"
            docker rmi -f "${IMAGEID}" || true
            echo ""
        fi
    fi
}

function build {
    TOOL_NAME=$1
    if has_changed "${TOOL_NAME}" || [[ $(echo "${SLH_BUILD_ALL}" | tr [:upper:] [:lower:]) == "true"  ]];
    then
        
        VERSION=$(get_tool_version "$TOOL_NAME") # Must be prior to CWD change.

        echo "Building image '${TOOL_NAME}'"
        cd "${TOOLS_FOLDER}/${TOOL_NAME}"

        cp -r ../../helpers ./assets

        DOCKER_BUILD_ARGS="--build-arg VERSION=${VERSION}"
        if [[ -f "pre-build.sh" ]]; then
          echo "Executing pre-build script for '${TOOL_NAME}'"
          # shellcheck disable=SC1091
           trap ". post-build.sh && exit 1" EXIT # ensure cleanup, if pre-build.sh fails
           # shellcheck disable=SC1091
           . pre-build.sh
           trap - EXIT
        fi

        # We need to disable the shell failing automatically after a docker build fail.
        # If we do, we do not run post-build.sh and therefore no cleanup is done
        set +e
        # shellcheck disable=SC2086
        docker build -t ${SUITE_NAME}/${TOOL_NAME}:latest --no-cache --rm=true ${DOCKER_BUILD_ARGS} .
        DOCKER_BUILD_STATUS=$?
        set -e # re-enable exit on non-zero status

        if [[ -f "post-build.sh" ]]; then
          echo "Executing post-build script for '${TOOL_NAME}'"
          # shellcheck disable=SC1091
          . post-build.sh
        fi

        rm -Rf ./assets/helpers
        echo ""
        return ${DOCKER_BUILD_STATUS}
    else
        echo "Image '${TOOL_NAME}' has not changed, nothing to build"
    fi
}

function has_changed {
    TOOL_NAME=$1

    # Consider the tool changed, if there are local changes not committed yet
    if git status -s | grep "${TOOLS_FOLDER}/${TOOL_NAME}" > /dev/null; then
      echo "Local changes (not committed) detected for ${TOOL_NAME}"
      return 0
    fi

    latest=$(get_non_merge_commit)
    ancestor=$(get_common_ancestor "${latest}")

    # Get diff from common ancestor to latest and fetch changes to the
    # respective tool. If the PRB is running (aka the current branch is not
    # master) then also consider changes to the build infrastructure, i.e. in
    # that case all tools are considered changed. 
    if on_master; then
        FILES=$(git diff --name-only "${ancestor}..${latest}" | grep -e "${TOOLS_FOLDER}/${TOOL_NAME}")
    else
        FILES=$(git diff --name-only "${ancestor}..${latest}" | grep -e "${TOOLS_FOLDER}/${TOOL_NAME}" -e "make.sh" -e "Makefile" -e "helpers/" -e "${TOOLS_FOLDER}/installer/assets/execute")
    fi

    if [ -n "${FILES}" ];
    then
        return 0
    else
        return 1
    fi
}

function on_master {
    if [ "${CURRENT_BRANCH}" = "master" ]; then
        return 0
    fi
    return 1
}

# Return the earliest common ancestor of master and the given branch.
function get_common_ancestor {
  latest=$1
  diff -u <(git rev-list --first-parent "${latest}") <(git rev-list --first-parent origin/master) | sed -ne 's/^ //p' | head -1
}

# Return the latest non merge commit. If HEAD is regular commit (only one
# parent) return itself. If there are multiple parent, return the last. Fine as
# octopus-merges are not common for us, I guess.
function get_non_merge_commit {
  parents=$(git cat-file commit HEAD | sed -ne 's/^parent //p')
  latest=HEAD
  if [[ $(echo "${parents}" | wc -w) -eq 2 ]]; then
    latest=$(echo "${parents}" | tr ' ' '\n' | tail -1)
  fi
  echo "${latest}"
}

# Check the given tool for different aspects:
# * If the tool was changed:
#   * Run static code analysis for bash scripts using the shellcheck.
# * If the tool has changed and we're on master (aka during the CI build):
#   * Verify no container with the given version exists in the repository.
function check {
    TOOL_NAME=$1

    if has_changed "$TOOL_NAME"; then
        FILES=$(find "${TOOLS_FOLDER}/${TOOL_NAME}" -type f -name '*.sh' -o -name 'execute')
        if [[ -n "${FILES}" ]]; then
            # sc=$(mktemp)
            # sed -e "/^TOOL_NAME=/ s/\"\"/shellcheck/" tools/installer/assets/execute > "$sc"
            # trap 'rm $sc' RETURN
            # chmod +x "$sc"

            echo "Test shell scripts for tool \"${TOOL_NAME}\": $(echo "${FILES}" | sed "s;${TOOLS_FOLDER}/${TOOL_NAME}/;;g" | tr '\n' ' ')"
            # shellcheck disable=SC2086
            shellcheck -a -f gcc ${FILES}
        fi
    fi

    if on_master && has_changed "${TOOL_NAME}";
    then
        echo "Found change for '${TOOL_NAME}'"
        VERSION=$(cat "${TOOLS_FOLDER}/${TOOL_NAME}/VERSION")
        if docker pull "${SUITE_NAME}/${TOOL_NAME}:${VERSION}" &>/dev/null; then
            echo "'${TOOL_NAME}' has been changed, but the version seems to be the same"
            echo "Please update ${TOOLS_FOLDER}/${TOOL_NAME}/VERSION and ${TOOLS_FOLDER}/${TOOL_NAME}/README.md for this PRB to succeed."
            exit 1
        else
            echo "'${TOOLS_FOLDER}/${TOOL_NAME}' has been changed, but found updated VERSION. Good job!"
        fi
    else
        echo "Component '${TOOL_NAME}' passed the VERSION test."
    fi
}

function get_tool_version {
    TOOL_NAME=$1
    sed -e 's;-[^-]*$;;' < "$TOOLS_FOLDER/$TOOL_NAME/VERSION"
}

function install_sledgehammer {
    # install sledgehammer to the bin directory and install the slh-development toolkit
    if [ ! -f ./bin/slh ]; then
        mkdir bin
        docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/bin:/data adobe/slh
        ./bin/slh install slh-dev --kit
    fi
}

case "$1" in
    clean)
            clean "$2"
            ;;
    build)
            build "$2"
            ;;
    verify)
            verify "$2"
            ;;
    release)
            release "$2"
            ;;
    check)
            check "$2"
            ;;
    install)
            install_sledgehammer
            ;;
        *)
            echo "Usage: $0 {build|clean|verify|release|check} <tool_name>"
            exit 1
esac
