#!/usr/bin/env bash
set -euo pipefail
url="${1:-http://127.0.0.1:4177}"
browser() { npx --yes agent-browser --session yapper-verify "$@"; }
trap 'browser close >/dev/null 2>&1' EXIT
browser open "$url"
browser set viewport 1440 1000
browser wait --load networkidle
browser eval 'if(document.querySelectorAll("h1").length!==1)throw Error("Expected one page heading"); if(![...document.querySelectorAll("a[download]")].every(a=>a.getAttribute("href")==="/downloads/Yapper-latest.dmg"))throw Error("Download URL mismatch"); "Page structure passed"'
for index in 1 2 3; do
  browser scrollintoview ".demo-tabs button:nth-child($index)"
  browser click ".demo-tabs button:nth-child($index)"
  browser scrollintoview '.demo-pill'
  browser click '.demo-pill'
  browser wait --text "That's your thought, typed."
  case "$index" in
    1) expected="Hey Maya, let's move our catch-up to Thursday. I have something good to show you." ;;
    2) expected="What if the best part of the product was how little you had to think about using it?" ;;
    3) expected="Remember to book the little place by the ocean for next weekend." ;;
  esac
  actual="$(browser get text '.letter-body p')"
  [[ "$actual" == "$expected" ]] || { echo "Demo $index returned unexpected text" >&2; exit 1; }
done
browser scrollintoview '.faq details:first-of-type summary'
browser click '.faq details:first-of-type summary'
browser eval 'if(!document.querySelector(".faq details").open)throw Error("FAQ did not open"); "FAQ passed"'
for width in 390 768 1440; do
  browser set viewport "$width" 900
  browser eval 'if(document.documentElement.scrollWidth>innerWidth)throw Error("Horizontal overflow"); "Responsive width passed"'
done
browser eval 'Promise.all([...document.querySelectorAll("a[download]")].map(async a=>{ const r=await fetch(a.href,{method:"HEAD"});if(!r.ok||Number(r.headers.get("content-length"))<1000000)throw Error("Installer is missing");})).then(()=>"Download checks passed")'
echo 'Yapper website verification passed.'
