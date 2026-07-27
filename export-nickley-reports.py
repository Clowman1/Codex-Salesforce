import json
import subprocess
import urllib.request
from pathlib import Path

from openpyxl import Workbook


SF = r"C:\Program Files\sf\bin\sf.cmd"
SF_PROJECT = r"C:\Users\ChristopherLowman\Documents\Codex\2026-05-11\what-all-are-you-able-to-2\salesforce-work"
TARGET_ORG = "my-org"
OUTPUT_DIR = Path(r"C:\Users\ChristopherLowman\Desktop\Nickley Reports")
API_VERSION = "66.0"

REPORTS = [
    ("Contracts From Nickley (This Month)", "00OQi000000wTsrMAE", "Contracts From Nickley (This Month).xlsx"),
    ("Nickley Leads This Month", "00OQi000004m3u9MAA", "Nickley Leads This Month.xlsx"),
    ("Nickley Realtor Lookback Last Week", "00OQi000002w0CzMAI", "Nickley Realtor Lookback Last Week.xlsx"),
    ("Nickley Pre-Approvals This Month", "00OQi000005ZLrVMAW", "Nickley Pre-Approvals This Month.xlsx"),
]


def sf_org():
    raw = subprocess.check_output(
        [SF, "org", "display", "--target-org", TARGET_ORG, "--verbose", "--json"],
        cwd=SF_PROJECT,
        text=True,
    )
    return json.loads(raw)["result"]


def request_json(url, token):
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)


def cell_value(cell):
    value = cell.get("value")
    if isinstance(value, dict):
        if "amount" in value:
            return value["amount"]
        return cell.get("label")
    if value is None:
        return ""
    return value


def export_report(instance_url, token, report_name, report_id, file_name):
    url = f"{instance_url}/services/data/v{API_VERSION}/analytics/reports/{report_id}?includeDetails=true"
    report = request_json(url, token)
    metadata = report["reportMetadata"]
    extended = report["reportExtendedMetadata"]["detailColumnInfo"]
    columns = metadata.get("detailColumns", [])
    headers = [extended.get(column, {}).get("label", column) for column in columns]

    rows = []
    seen = set()
    for fact in report.get("factMap", {}).values():
        for row in fact.get("rows", []) or []:
            values = tuple(cell_value(cell) for cell in row.get("dataCells", []))
            if values not in seen:
                seen.add(values)
                rows.append(values)

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Report"
    sheet.append(headers)
    for row in rows:
        sheet.append(list(row))
    for column_cells in sheet.columns:
        max_length = max(len(str(cell.value or "")) for cell in column_cells)
        sheet.column_dimensions[column_cells[0].column_letter].width = min(max(max_length + 2, 12), 45)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / file_name
    workbook.save(output_path)
    return {
        "name": report_name,
        "path": str(output_path),
        "rows": len(rows),
        "columns": len(headers),
        "size": output_path.stat().st_size,
    }


def main():
    org = sf_org()
    results = [
        export_report(org["instanceUrl"], org["accessToken"], name, report_id, file_name)
        for name, report_id, file_name in REPORTS
    ]
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
