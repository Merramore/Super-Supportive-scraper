#!/bin/bash
#fetch.sh
# ...

set -e


INDEX_URL='https://www.royalroad.com/fiction/63759/super-supportive'
INDEX_FILE='book/super-supportive.html'
CHAPTER_LIST_FILE='book/chapters.txt'
CHAPTER_GREP_PREFIX='/fiction/63759/super-supportive/chapter/'
CHAPTER_URL_PREFIX='https://www.royalroad.com/fiction/63759/super-supportive/chapter/'
REQUEST_GAP=2


now="$(date +@%s.%Ns)"

_with() { "${@}"; }



# rate-limited curl
curtl() {
    curl "${@}"
    sleep "${REQUEST_GAP}"
}


common_randoms=(
    -e 's/<meta name="sentry-trace"[^>]*>/<meta name="sentry-trace" \/>/g'
    -e 's/<meta name="baggage"[^>]*>/<meta name="baggage" \/>/g'
    -e 's/<input name="__RequestVerificationToken" type="hidden"[^>]*>/<input name="__RequestVerificationToken" type="hidden" \/>/g'
    -e 's/email-protection#[^"]*/email-protection#/g'
    -e 's/window.__CF$cv$params={[^\}]*}/window.__CF$cv$params={}/g'
)
strip_common_randoms() {
    sed \
      "${common_randoms[@]}" \
      -i "${1}"
}

index_randoms=(
    -e 's/star-63759-overall-[a-zA-Z0-9_-]*/star-63759-overall-/g'
)
strip_index_randoms() {
    sed \
      "${common_randoms[@]}" \
      "${index_randoms[@]}" \
      -i "${1}"
}

chapter_randoms=(
    -e 's/<p class="c[^"]*"/<p class="_cContent"/g'
)
strip_chapter_randoms() {
    local antitheft="$(grep -Poe '(?<=\.)c[a-zA-Z0-9_-]*(?=\{)' "${1}" || echo _cAntitheft)"
    # sed equivalent: -e 's/\.c[a-zA-Z0-9_-]\+{/\._cAntiTheft{b/g'
    sed \
      -e "s/${antitheft}/_cAntiTheft/g" \
      -e 's/<p class="_cAntiTheft".*\?<\/p[^>]*>//g' \
      "${common_randoms[@]}" \
      "${chapter_randoms[@]}" \
      -i "${1}"
}


do_fetch() {
    mkdir -p 'book/chapters'

    printf 'Downloading: %q\n' >&2 "${INDEX_FILE}"
    curtl -o "${INDEX_FILE}" "${INDEX_URL}"
    # deduplicate and sort
    grep -Poe "(?<=${CHAPTER_GREP_PREFIX})[^\"]*" "${INDEX_FILE}" | python -c 'import sys; print("\n".join(sorted(set(sys.stdin.read().splitlines()))))' >"${CHAPTER_LIST_FILE}"
    # pretty after parsing
    strip_index_randoms "${chapter_file}"
    # lol msys
    sed -i 's/\r\n/\n/g' "${CHAPTER_LIST_FILE}"


    local chapters=()
    local chapter_files=()
    #local chapter_urls

    while read -r chapter; do
        chapters+=("${chapter}")
        #printf >&2 '%s %q\n' "n=${#chapters[@]}" "${chapter}"
        #[[ "${#chapters[@]}" -gt 0 ]]
        #chapter_urls+="(${CHAPTER_URL_PREFIX}${chapter}")
    done <"${CHAPTER_LIST_FILE}"
    #echo >&2 "n=${#chapters[@]}"

    while read -r chapter_designation; do
        chapter_files+=("book/chapters/${chapter_designation}.html")
        #[[ "${#chapter_files[@]}" -gt 0 ]]
        #printf >&2 '%s %q\n' "m=${#chapter_files[@]}" "${chapter_designation}"
    done < <(python3 <"${CHAPTER_LIST_FILE}" -c 'import sys, urllib.parse; sys.stdout.write("".join(urllib.parse.quote(line, safe=" ")+"\n" for line in sys.stdin.read().replace("/", " ").splitlines() if line))' | sed -e 's/\r//g')
    #echo >&2 "m=${#chapter_files[@]}"

    local i=0
    while [[ "${i}" -lt "${#chapters[@]}" ]]; do
        local chapter="${chapters["${i}"]}"
        local chapter_file="${chapter_files["${i}"]}"
        #local chapter_url="${chapter_urls["${i}"]}"
        local chapter_url="${CHAPTER_URL_PREFIX}${chapter}"
        #printf >&2 ' %q' curtl -o "${chapter_file}" "${chapter_url}"; echo >&2
        printf 'Downloading: %q\n' >&2 "${chapter_file}"
        curtl -o "${chapter_file}" "${chapter_url}"
        strip_chapter_randoms "${chapter_file}"
        i="$(("${i}" + 1))"
    done
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
    git checkout -f 'fetch'
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
      >"logs/fetch-curl ${now} stdout.log" \
      2>"logs/fetch-curl ${now} stderr.log"
} # run_and_log()

run_and_tee_log() {
    mkdir -p logs
    run \
      > >(tee "logs/fetch-curl ${now} stdout.log") \
      2> >(tee >&2 "logs/fetch-curl ${now} stderr.log")
} # run_and_tee_log()


usage() {
    printf >&2 '%q' "${0}";
    echo >&2 "\n  run\n  run_and_log\n  run_and_tee_log\n  do_fetch\n  strip_chapter_randoms <file>"
} # usage()



case "${1}" in
    run) run;;
    run_and_log) run_and_log;;
    run_and_tee_log) run_and_tee_log;;
    do_fetch) do_fetch;;
    strip_common_randoms) strip_common_randoms "${2}";;
    strip_index_randoms) strip_index_randoms "${2}";;
    strip_chapter_randoms) strip_chapter_randoms "${2}";;
    *) usage;;
esac
