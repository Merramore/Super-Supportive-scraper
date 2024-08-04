#!/bin/bash
#fetch.sh
# ...

set -e


INDEX_URL='https://www.royalroad.com/fiction/63759/super-supportive'
INDEX_FILE='book/super-supportive.html'
CHAPTER_LIST_FILE='book/chapters.txt'
CHAPTER_GREP_PREFIX='/fiction/63759/super-supportive/chapter/'
CHAPTER_URL_PREFIX='https://www.royalroad.com/fiction/63759/super-supportive/chapter/'


now="$(date +@%s.%Ns)"


do_fetch() {
    mkdir -p 'book/chapters'

    #curl -o "${INDEX_FILE}" "${INDEX_URL}"
    # deduplicate and sort
    grep -Poe "(?<=${CHAPTER_GREP_PREFIX})[^\"]*" "${INDEX_FILE}" | python -c 'import sys; print("\n".join(sorted(set(sys.stdin.read().splitlines()))))' >"${CHAPTER_LIST_FILE}"
    # lol msys
    sed -i 's/\r\n/\n/g' "${CHAPTER_LIST_FILE}"

    local 
    cat "${CHAPTER_LIST_FILE}" | while read -r chapter; do
        local chapter_file="book/chapters/$(python3 -c 'import sys, urllib.parse; sys.stdout.write(urllib.parse.quote(sys.argv[1].replace("/", " "), safe=" "))' "${chapter}").html"
        local chapter_url="${CHAPTER_URL_PREFIX}${chapter}"
        printf >&2 ' %q' curl -o "${chapter_file}" "${chapter_url}"; echo >&2
        #curl -o "${chapter_file}" "${chapter_url}" && sleep 2
    done

    git add 'book/'
    git commit -m "Royal Road fetch at ${now}"
} # do_fetch()


git_prefetch() {
    # autocommit
    local last_rev="$(git rev-parse HEAD)"
      # test commit failure because sometimes diff --staged returns true when nothing is staged
    if git diff --cached --exit-code --quiet \
      && git commit -m "Pre-fetch autocommit of staged changes\nFrom: ${last_rev}\nTime: ${now}" \
    ; then
        if git diff --exit-code --quiet; then
            git add --all
            git commit -m "Pre-fetch autocommit of unstaged or untracked changes\nFrom: ${last_rev}\nTime: ${now}" || true
        fi
        git tag "prefetch-autocommit-${now}"
    elif git diff --exit-code --quiet; then
        git add --all
        if git commit -m "Pre-fetch autocommit unstaged\nFrom: ${last_rev}\nTime: ${now}"
        then
            git tag "prefetch-autocommit-${now}"
        fi
    fi
    git checkout -f 'fetch'
}

git_postfetch() {
    if git diff --exit-code --quiet || git diff --cached --exit-code --quiet; then
        git add --all
        git commit -m "Fetch at ${now}"
    fi
}

#git branch --show-current


run() {
    git_prefetch
    do_fetch
    git_postfetch
}

run_and_log() {
    mkdir -p logs
    run \
      >"logs/fetch ${now} stdout.log" \
      2>"logs/fetch ${now} stderr.log"
}

run_and_tee_log() {
    mkdir -p logs
    run \
      > >(tee "logs/fetch ${now} stdout.log") \
      2> >(tee >&2 "logs/fetch ${now} stderr.log")
}


usage() {
    printf >&2 '%q' "${0}";
    echo >&2 " run|run_and_log|run_and_tee_log|do_fetch"
}



case "${1}" in
    run) run;;
    run_and_log) run_and_log;;
    run_and_tee_log) run_and_tee_log;;
    do_fetch) do_fetch;;
    *) usage;;
esac
