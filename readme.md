# Super Supportive versioning scraper

Scrapes the [current public version of Super Supportive from Royal Road](https://www.royalroad.com/fiction/63759/super-supportive) and commits it to git for edit tracking.

I wrote two versions: one with a bespoke curl backend, then one using Fanficfare.
Fanficfare produces cleaner output due to stripping more superflous page elements (comments & worse), but both have postprocessing steps to pull out random garbage.

## Requirements
`bash` `git` `curl` `grep` `sed` `python3`

## Setup

Init a new git repo.

```bash
mkdir super-supportiove-royal-road
cd super-supportiove-royal-road
git init .
```


### Fanficfare version setup
```bash
pip install fanficfare
```

Use a venv or something first probably.

```bash
python -m venv -prompt super-supportive-royal-road venv
source venv/bin/activate || source venv/Scripts/activate
```

## Usage

Run from the intended output folder.

```bash1
bash fetch-<variant>.sh run
```

`fetch-curl.sh` will create, checkout, and commit to the `fetch` branch.

`fetch-fanficfare.sh` will create, checkout, and commit to the `fanficfare` branch.

**Both variants will commit any untracked or modified files before forcing a checkout.**\
This is failsafe both for scheduled runs and for running from the wrong directory by mistake.

Output structure:
> - `./book/`
>   - `super_supportive.html` curl  downloaded index
>   - `chapters.txt` curl parsed index
>   - `chapters/` curl chapters
>     - `*.html`
>   - `Super Supportive-<...>.html` fanficfare book
>   - `Super Supportive-<...>.json` fanficfare metadata
> - `./logs/`
>   - `*.log`

`run` just prints to stdout.
`run_*_log` are for logging for scheduled pulls.
The rest of the commands are internal/debug.
