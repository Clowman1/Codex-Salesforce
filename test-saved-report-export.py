import json
import re
import subprocess
import urllib.parse
import urllib.request
import http.cookiejar
from pathlib import Path

SF = r"C:\Program Files\sf\bin\sf.cmd"
SF_PROJECT = r"C:\Users\ChristopherLowman\Documents\Codex\2026-05-11\what-all-are-you-able-to-2\salesforce-work"
REPORT_ID = "00OQi000000wTsrMAE"

org = json.loads(
    subprocess.check_output(
        [SF, "org", "display", "--target-org", "my-org", "--verbose", "--json"],
        cwd=SF_PROJECT,
        text=True,
    )
)["result"]

cookies = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))

classic_path = f"/{REPORT_ID}?export=1&enc=UTF-8&xf=xls"
frontdoor = (
    f"{org['instanceUrl']}/secur/frontdoor.jsp?sid={urllib.parse.quote(org['accessToken'])}"
    f"&retURL={urllib.parse.quote(classic_path, safe='')}"
)
next_url = frontdoor
data = b""
for _ in range(8):
    data = opener.open(next_url, timeout=120).read()
    text = data[:10000].decode("utf-8", "replace")
    match = re.search(r"window\.location\.replace\(['\"]([^'\"]+)['\"]\)", text)
    if not match:
        match = re.search(r'href="(https://[^"]+)"', text)
    if not match:
        break
    next_url = match.group(1).replace("&amp;", "&")

path = Path(r"C:\Users\ChristopherLowman\Desktop\Nickley Reports\_test_saved_report_2.xls")
path.write_bytes(data)
print(next_url)
print(len(data), data[:80])
print(data[:300].decode("utf-8", "replace"))
