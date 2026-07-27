import csv
import json
import subprocess
from datetime import datetime
from pathlib import Path


OUTPUT = Path("may_2026_reach_post_closed_primary_myhomeiq.csv")

HEADERS = [
    "street",
    "unit",
    "city",
    "state",
    "zip",
    "name",
    "email",
    "phone",
    "coborrower name",
    "coborrower email",
    "coborrower phone",
    "loan_amount",
    "sale_price",
    "loan_amortization_period",
    "interest_rate",
    "loan_date",
    "home_value",
    "appraised value",
    "tags",
]

SOQL = """
SELECT
  Id,
  Name,
  Status__c,
  Funding_Date__c,
  Biz_Dev__c,
  Occupancy__c,
  Property_Address__c,
  Property_Unit__c,
  Property_City__c,
  Property_State__c,
  Property_Postal_Code__c,
  Borrower_Name__r.Name,
  Borrower_First_Name__c,
  Borrower_Last_Name__c,
  Borrower_Email__c,
  Borr_Email__c,
  Borrowers_Phone__c,
  Borrower_Home_Phone__c,
  Email_Co_Borrower__c,
  Loan_Amount__c,
  Loan_Amount_1st__c,
  Purchase_Price__c,
  Term_1st__c,
  Interest_Rate__c,
  Rate_1st_TD__c,
  Appraised_Value__c,
  Property_Original_Cost__c
FROM Transaction__c
WHERE Status__c = 'Post-Closed'
AND Funding_Date__c >= 2026-05-01
AND Funding_Date__c < 2026-06-01
AND Biz_Dev__c = 'Biz Dev - Reach'
AND Occupancy__c IN ('Primary', 'Primary Residence')
ORDER BY Funding_Date__c, Name
"""


def run_sf_query():
    soql = " ".join(SOQL.split())
    cmd = [
        r"C:\Program Files\sf\bin\sf.cmd",
        "data",
        "query",
        "--target-org",
        "my-org",
        "--query",
        soql,
        "--json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.stdout + "\n" + result.stderr)
    return json.loads(result.stdout)


def get_path(record, dotted):
    value = record
    for part in dotted.split("."):
        if not isinstance(value, dict):
            return None
        value = value.get(part)
    return value


def first_present(*values):
    for value in values:
        if value not in (None, ""):
            return value
    return ""


def clean(value):
    if value in (None, ""):
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    if isinstance(value, str):
        return " ".join(value.split())
    return value


def date_only(value):
    if not value:
        return ""
    text = str(value)
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            pass
    return text[:10]


def amortization_period(value):
    if value in (None, ""):
        return ""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return clean(value)
    if number >= 12 and number % 12 == 0:
        number = number / 12
    if number.is_integer():
        return str(int(number))
    return str(number)


def borrower_name(record):
    first = clean(record.get("Borrower_First_Name__c"))
    last = clean(record.get("Borrower_Last_Name__c"))
    joined = " ".join(part for part in [first, last] if part)
    return joined or clean(get_path(record, "Borrower_Name__r.Name"))


def mapped_row(record):
    appraised_value = first_present(record.get("Appraised_Value__c"), record.get("Property_Original_Cost__c"))
    return {
        "street": clean(record.get("Property_Address__c")),
        "unit": clean(record.get("Property_Unit__c")),
        "city": clean(record.get("Property_City__c")),
        "state": clean(record.get("Property_State__c")),
        "zip": clean(record.get("Property_Postal_Code__c")),
        "name": borrower_name(record),
        "email": clean(first_present(record.get("Borrower_Email__c"), record.get("Borr_Email__c"))),
        "phone": clean(first_present(record.get("Borrowers_Phone__c"), record.get("Borrower_Home_Phone__c"))),
        "coborrower name": "",
        "coborrower email": clean(record.get("Email_Co_Borrower__c")),
        "coborrower phone": "",
        "loan_amount": clean(first_present(record.get("Loan_Amount__c"), record.get("Loan_Amount_1st__c"))),
        "sale_price": clean(record.get("Purchase_Price__c")),
        "loan_amortization_period": amortization_period(record.get("Term_1st__c")),
        "interest_rate": clean(first_present(record.get("Interest_Rate__c"), record.get("Rate_1st_TD__c"))),
        "loan_date": date_only(record.get("Funding_Date__c")),
        "home_value": clean(appraised_value),
        "appraised value": clean(appraised_value),
        "tags": "Post-Closed; Biz Dev - Reach; Primary Occupancy; May 2026",
    }


def main():
    payload = run_sf_query()
    records = payload["result"]["records"]
    rows = [mapped_row(record) for record in records]
    with OUTPUT.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=HEADERS)
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({"output": str(OUTPUT.resolve()), "record_count": len(rows)}, indent=2))


if __name__ == "__main__":
    main()
