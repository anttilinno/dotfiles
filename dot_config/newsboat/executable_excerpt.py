#!/usr/bin/env python3
"""Newsboat filter: prepend an excerpt of the linked article to each item.

Link-only feeds (HN, Lobsters) carry no content, so the article view gives
nothing to decide on. Fetch each link once, take og:description plus the
first real paragraphs, and put them at the top of the item description.

Usage in urls: "filter:/home/antti/.config/newsboat/excerpt.py:https://hnrss.org/frontpage"
"""
import hashlib
import html
import io
import os
import sys
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from urllib.request import Request, urlopen

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "newsboat-excerpts")
UA = "Mozilla/5.0 (X11; Linux x86_64) newsboat"
SKIP = {"script", "style", "nav", "header", "footer", "aside", "form"}
MAX_CHARS = 700


class Extract(HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = ""
        self.paras = []
        self._p = None
        self._skip = 0

    def _flush(self):
        if self._p is not None:
            text = " ".join("".join(self._p).split())
            if len(text) > 80:
                self.paras.append(text)
            self._p = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "meta" and not self.meta and (a.get("property") or a.get("name")) in ("og:description", "description"):
            self.meta = " ".join((a.get("content") or "").split())
        elif tag in SKIP:
            self._skip += 1
        elif tag == "p" and not self._skip:
            self._flush()
            self._p = []

    def handle_endtag(self, tag):
        if tag in SKIP and self._skip:
            self._skip -= 1
        elif tag == "p":
            self._flush()

    def handle_data(self, data):
        if self._p is not None and not self._skip:
            self._p.append(data)


def summarise(page):
    p = Extract()
    p.feed(page)
    p._flush()
    out, n = [], 0
    for text in [p.meta] + p.paras:
        if not text or n >= MAX_CHARS or any(text[:60] == o[:60] for o in out):
            continue
        out.append(text if n + len(text) <= MAX_CHARS else text[: MAX_CHARS - n].rsplit(" ", 1)[0] + " …")
        n += len(out[-1])
    return out


def excerpt(url):
    path = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest())
    try:
        with open(path, encoding="utf-8") as f:
            return [x for x in f.read().split("\n\n") if x]
    except FileNotFoundError:
        pass
    paras = []
    try:
        with urlopen(Request(url, headers={"User-Agent": UA}), timeout=8) as r:
            if "html" in r.headers.get("Content-Type", ""):
                page = r.read(2_000_000).decode(r.headers.get_content_charset() or "utf-8", "replace")
                paras = summarise(page)
    except Exception:
        pass  # ponytail: failures cache as empty and are never retried; delete the cache file to refetch
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(paras))
    return [x for x in paras if x]


def main():
    os.makedirs(CACHE, exist_ok=True)
    cutoff = time.time() - 30 * 86400
    for name in os.listdir(CACHE):
        full = os.path.join(CACHE, name)
        if os.path.getmtime(full) < cutoff:
            os.remove(full)

    data = sys.stdin.buffer.read()
    for _, (prefix, uri) in ET.iterparse(io.BytesIO(data), events=("start-ns",)):
        ET.register_namespace(prefix, uri)
    root = ET.fromstring(data)
    items = root.findall("./channel/item")
    links = [i.findtext("link") or "" for i in items]
    with ThreadPoolExecutor(16) as pool:
        results = list(pool.map(lambda u: excerpt(u) if u.startswith("http") else [], links))
    for item, paras in zip(items, results):
        if not paras:
            continue
        desc = item.find("description")
        if desc is None:
            desc = ET.SubElement(item, "description")
        blurb = "".join(f"<p>{html.escape(t)}</p>" for t in paras)
        desc.text = blurb + "<hr>" + (desc.text or "")
    sys.stdout.buffer.write(ET.tostring(root, encoding="utf-8", xml_declaration=True))


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        page = ('<meta property="og:description" content="Meta  blurb.">'
                '<nav><p>' + "menu " * 30 + '</p></nav><p>short</p>'
                '<p>' + "body text " * 10 + '<p>' + "second para " * 10)
        got = summarise(page + '<p>' + "body text " * 12 + '</p>')
        assert got[0] == "Meta blurb.", got
        assert got[1].startswith("body text") and "menu" not in " ".join(got), got
        assert got[2].startswith("second para"), got
        print("ok")
    else:
        main()
