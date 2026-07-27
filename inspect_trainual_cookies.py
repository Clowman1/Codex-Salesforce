import os
import sqlite3
from pathlib import Path

cookie_path = Path(os.environ["LOCALAPPDATA"]) / "Google" / "Chrome" / "User Data" / "Default" / "Network" / "Cookies"
uri = f"{cookie_path.as_uri()}?mode=ro"
con = sqlite3.connect(uri, uri=True)
rows = list(
    con.execute(
        "select host_key, name, path, expires_utc, length(encrypted_value) from cookies where host_key like ? order by host_key, name",
        ("%trainual%",),
    )
)
print(rows[:100])
print("count", len(rows))
