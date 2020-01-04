#!/bin/bash

SKIP_TARGET=1
if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
    head_commit_message="$(echo "${GITHUB_CONTEXT}" | jq -crMe ".event.head_commit.message")"
    if [[ $head_commit_message =~ \#target=(.*)\# ]]; then
        head_commit_message_target="${BASH_REMATCH[1]}" 
        echo "Commit message target: ${head_commit_message_target}"
        if [ "x${head_commit_message_target}" = "xall" -o "x${head_commit_message_target}" = "x${BUILD_TARGET}" ]; then
            SKIP_TARGET=0
        fi
    else
        commit_before=$(echo "${GITHUB_CONTEXT}" | jq -crM '.event.before // ""')
        commit_after=$(echo "${GITHUB_CONTEXT}" | jq -crM '.event.after // ""')
        if [ -z "${commit_before}" -o -z "${commit_after}" ]; then
            echo "::error::Oops! Something went wrong! Github push event does not exist!" >&2
            exit 1
        fi

        # when forcing push, we cannot compare
        if git cat-file -e ${commit_before}^{commit} ; then
            echo "Changes in this push:"
            git --no-pager diff --name-status ${commit_before} ${commit_after}
            changed_files="$(git --no-pager diff --name-only ${commit_before} ${commit_after})"

            BUILD_TARGET_ESC="$(echo "${BUILD_TARGET}" | sed 's/[^[:alnum:]_-]/\\&/g')"
            set +e
                echo "${changed_files}" | grep -q '^user/'"${BUILD_TARGET_ESC}"'/'
                ret_val=$?
            set -e

            if [ ${ret_val} -eq 0 ]; then
                echo "File changes of current target detected"
                SKIP_TARGET=0
            fi
        else
            echo "::error::Force push detected, we cannot compare file changes" >&2
        fi
    fi

elif [ "x${RD_TASK}" = "xbuild" ]; then
    echo "Repo dispatch or deployments event target: ${RD_TARGET}"
    if [ "x${RD_TARGET}" = "xall" -o "x${RD_TARGET}" = "x${BUILD_TARGET}" ]; then
        SKIP_TARGET=0
    fi
else
    echo "::warning::Unknown triggering event, no skipping" >&2
    SKIP_TARGET=0
fi

if [ "x${SKIP_TARGET}" = "x1" ]; then
    echo "Skipping current job"
else
    echo "Not skipping current job"
fi
echo "::set-env name=SKIP_TARGET::${SKIP_TARGET}"