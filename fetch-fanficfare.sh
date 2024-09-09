#!/bin/bash
#fetch.sh
# ...

set -e


STORY_URL='https://www.royalroad.com/fiction/63759/super-supportive'
STORY_FILE='Super Supportive-rylrdl_63759.html'
JSON_FILE='Super Supportive-rylrdl_63759.json'


now="$(date +@%s.%Ns)"

_with() { "${@}"; }



# rate-limited curl
curtl() {
    curl "${@}"
    sleep "${REQUEST_GAP}"
}


story_randoms=(
    -e 's/<p class="c[^"]*"/<p class="_cContent"/g'
    -e 's/<meta name="sentry-trace"[^>]*>/<meta name="sentry-trace" \/>/g'
    -e 's/<meta name="baggage"[^>]*>/<meta name="baggage" \/>/g'
    -e 's/<input name="__RequestVerificationToken" type="hidden"[^>]*>/<input name="__RequestVerificationToken" type="hidden" \/>/g'
    -e 's/email-protection#[^"]*/email-protection#/g'
    -e 's/window.__CF$cv$params={[^\}]*}/window.__CF$cv$params={}/g'
)
strip_story_randoms() {
    sed \
      "${story_randoms[@]}" \
      -i "${1}"
}


do_fetch() {
    #fanficfare_cmd=("$(realpath venv/Scripts/fanficfare)")
    #fanficfare_cmd=(venv/Scripts/python -m fanficfare)
    fanficfare_cmd=(fanficfare)

    mkdir -p 'book'

    (
        cd book

        mv -f "${STORY_FILE}" "${STORY_FILE}.bak" 2>&- || true
        mv -f "${JSON_FILE}" "${JSON_FILE}.bak" 2>&- || true
        if (
            "${fanficfare_cmd[@]}" \
              --non-interactive \
              --json-meta \
              --format=html \
              "${STORY_URL}" \
              >"${JSON_FILE}"
        ); then
            rm -f "${STORY_FILE}.bak"
            rm -f "${JSON_FILE}.bak"
        else
            mv -f "${STORY_FILE}.bak" "${STORY_FILE}" 2>&- || true
            mv -f "${JSON_FILE}.bak" "${JSON_FILE}" 2>&- || true
        fi

        strip_story_randoms "${STORY_FILE}"
    )
} # do_fetch()


git_prefetch() {
    # autocommit
    local last_rev="$(git rev-parse HEAD)"
      # test commit failure because sometimes diff --staged returns true when nothing is staged
    if git diff --cached --exit-code --quiet \
      && git commit -m "Pre-fetch autocommit of staged changes\nFrom: ${last_rev}\nTime: ${now}" >&2 \
    ; then
        if git diff --exit-code --quiet; then
            git add --all
            git commit -m "Pre-fetch autocommit of unstaged or untracked changes\nFrom: ${last_rev}\nTime: ${now}" >&2 || true
        fi
        git tag "prefetch-autocommit-${now}"
    elif git diff --exit-code --quiet; then
        git add --all
        if git commit -m "Pre-fetch autocommit unstaged\nFrom: ${last_rev}\nTime: ${now}" >&2; then
            git tag "prefetch-autocommit-${now}"
        fi
    fi
    git branch 'fanficfare' 2>&- || true
    git checkout -f 'fanficfare'
} # git_prefetch()

git_postfetch() {
    if git diff --exit-code --quiet || git diff --cached --exit-code --quiet; then
        git add --all
        git commit -m "Fetch at ${now}" >&2
    fi
} # git_postfetch()

#git branch --show-current


run() {
    git_prefetch
    do_fetch
    git_postfetch
} # run()

run_and_log() {
    mkdir -p logs
    run \
      >"logs/fetch-fanfucfare ${now} stdout.log" \
      2>"logs/fetch-fanfucfare ${now} stderr.log"
} # run_and_log()

run_and_tee_log() {
    mkdir -p logs
    run \
      > >(tee "logs/fetch-fanfucfare ${now} stdout.log") \
      2> >(tee >&2 "logs/fetch-fanficfare ${now} stderr.log")
} # run_and_tee_log()


usage() {
    printf >&2 '%q' "${0}";
    echo >&2 $'\n  run\n  run_and_log\n  run_and_tee_log\n  do_fetch\n  strip_story_randoms <file>'
} # usage()



case "${1}" in
    run) run;;
    run_and_log) run_and_log;;
    run_and_tee_log) run_and_tee_log;;
    do_fetch) do_fetch;;
    strip_story_randoms) strip_story_randoms "${2}";;
    *) usage;;
esac
