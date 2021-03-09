#!/bin/bash

# Set some basic variables
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BASE_DIR="$( dirname $SCRIPTS_DIR )"
NEW_VERSION=
CAN_COMMIT=false
CAN_PUSH=false
CAN_DELETE=false
PRINT_NEW_VERSION=false
GENERATE_CHANGELOG=false
VERSIONED_FILES=( "$BASE_DIR/backend/setup.py" "$BASE_DIR/backend/ibutsu_server/openapi/openapi.yaml" "$BASE_DIR/frontend/package.json" )

function print_usage() {
    echo "Usage: make-release.sh [-h|--help] [-c|--commit] [-p|--push] [-d|--delete] [-g|--changelog] [VERSION]"
    echo ""
    echo "optional arguments:"
    echo "  -h, --help       show this help message"
    echo "  -v, --version    show the prospective new version number"
    echo "  -c, --commit     create a new branch and commit all the changes"
    echo "  -p, --push       push the branch up to origin after commit"
    echo "  -d, --delete     delete the branch after pushing"
    echo "  -g, --changelog  generate a changelog entry (needs 'git changelog')"
    echo "  VERSION          the new version, autogenerated if ommitted"
    echo ""
    echo "to generate a changelog, add the following line to the [alias] section"
    echo "in your .gitconfig file:"
    echo "  changelog = \"!_() { t=\$(git describe --abbrev=0 --tags); git log \${t}..HEAD --no-merges --pretty=format:'* %s'; }; _\""
    echo ""
}

# Parse the arguments
for ARG in $*; do
    if [[ "$ARG" == "-c" ]] || [[ "$ARG" == "--commit" ]]; then
        CAN_COMMIT=true
    elif [[ "$ARG" == "-p" ]] || [[ "$ARG" == "--push" ]]; then
        CAN_PUSH=true
    elif [[ "$ARG" == "-d" ]] || [[ "$ARG" == "--delete" ]]; then
        CAN_DELETE=true
    elif [[ "$ARG" == "-v" ]] || [[ "$ARG" == "--version" ]]; then
        PRINT_NEW_VERSION=true
    elif [[ "$ARG" == "-g" ]] || [[ "$ARG" == "--changelog" ]]; then
        GENERATE_CHANGELOG=true
    elif [[ "$ARG" == "-h" ]] || [[ "$ARG" == "--help" ]]; then
        print_usage
        exit 0
    else
        NEW_VERSION=$ARG
    fi
done

# Fetch the latest tags from upstream and set the current version
git fetch -q upstream
CURRENT_VERSION=`git tag --list | tail -n1 | cut -dv -f2`

if [[ "$NEW_VERSION" == "" ]]; then
    NEW_VERSION="${CURRENT_VERSION%.*}.$((${CURRENT_VERSION##*.}+1))"
fi

if [[ $PRINT_NEW_VERSION = true ]]; then
    echo "Prospective version number: $NEW_VERSION"
    exit 0
fi

echo "Updating files to $NEW_VERSION"
SED_VERSION=$(echo "$CURRENT_VERSION" | sed -r 's/[\.]+/\\\./g')
for FNAME in ${VERSIONED_FILES[@]}; do
    echo " - ${FNAME/$BASE_DIR\//}"
    sed -i "s/$SED_VERSION/$NEW_VERSION/g" $FNAME
done

if [[ $GENERATE_CHANGELOG = true ]]; then
    echo "Generating changelog entry"
    VERSION_TITLE="Version $NEW_VERSION"
    TITLE_LEN=$((${#VERSION_TITLE}+1))
    UNDERLINE=`seq -s "=" $TITLE_LEN | sed 's/[0-9]//g'`
    CHANGELOG=`git changelog`
    echo -e "$VERSION_TITLE\n$UNDERLINE\n\n$CHANGELOG\n\n$(cat $BASE_DIR/CHANGELOG.md)" > $BASE_DIR/CHANGELOG.md
fi

# Commit everything
if [[ "$CAN_COMMIT" = true ]]; then
    echo -n "Committing code..."
    BRANCH_NAME="release-$NEW_VERSION"
    git checkout -b $BRANCH_NAME > /dev/null 2>&1
    git add . > /dev/null 2>&1
    COMMIT_MSG="Release $NEW_VERSION"
    if [[ $GENERATE_CHANGELOG = true ]]; then
        COMMIT_MSG="$COMMIT_MSG\n\n$CHANGELOG"
    fi
    git commit -q -m "$COMMIT_MSG"
    echo "done, new branch created: $BRANCH_NAME"
    if [[ "$CAN_PUSH" = true ]]; then
        echo -n "Pushing up to origin/$BRANCH_NAME..."
        git push -q origin $BRANCH_NAME
        git checkout master
        if [[ "$CAN_DELETE" = true ]]; then
            git branch -D $BRANCH_NAME
            echo "Deleted branch $BRANCH_NAME"
        fi
    fi
fi
