/**
 * LeadThroughputTimeframe
 *
 * Pure date/window logic for Throughput Analytics timeframe filtering.
 * - No SOQL
 * - No DML
 *
 * Supported timeframe types (calendar-based):
 * - QUARTER_YEAR (union of selected quarters)
 * - YTD (Jan 1 current year through today)
 * - LAST_YEAR (prior calendar year)
 * - TWO_YEARS_AGO (calendar year two years prior)
 */
public with sharing class LeadThroughputTimeframe {
    private LeadThroughputTimeframe() {}

    public enum TimeframeType {
        QUARTER_YEAR,
        YTD,
        LAST_YEAR,
        TWO_YEARS_AGO
    }

    /**
     * A date window with inclusive bounds.
     */
    public class DateWindow {
        public Date startDate { get; private set; }
        public Date endDate { get; private set; }

        public DateWindow(Date startDate, Date endDate) {
            if (startDate == null || endDate == null) {
                throw new AuraHandledException('DateWindow requires both startDate and endDate.');
            }
            if (startDate > endDate) {
                throw new AuraHandledException('DateWindow startDate must be on or before endDate.');
            }
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }

    /**
     * A CreatedDate window with start inclusive, end exclusive (DateTime).
     * This matches existing repo conventions.
     */
    public class CreatedDateWindow {
        public DateTime startInclusive { get; private set; }
        public DateTime endExclusive { get; private set; }

        public CreatedDateWindow(DateTime startInclusive, DateTime endExclusive) {
            if (startInclusive == null || endExclusive == null) {
                throw new AuraHandledException('CreatedDateWindow requires both startInclusive and endExclusive.');
            }
            if (startInclusive >= endExclusive) {
                throw new AuraHandledException('CreatedDateWindow startInclusive must be before endExclusive.');
            }
            this.startInclusive = startInclusive;
            this.endExclusive = endExclusive;
        }
    }

    public static TimeframeType parseTimeframeType(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return TimeframeType.valueOf(raw.trim().toUpperCase());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Resolves the requested timeframe into one or more DateWindow(s) (inclusive).
     * - For YTD/LAST_YEAR/TWO_YEARS_AGO: returns a single window.
     * - For QUARTER_YEAR: returns windows for each selected quarter key.
     *
     * Quarter key formats supported:
     * - "YYYY-Qn" (preferred, e.g., "2025-Q1")
     * - "Qn YYYY" (tolerated, e.g., "Q1 2025")
     */
    public static List<DateWindow> resolveDateWindows(String timeframeType, List<String> quarterYearKeys, Date today) {
        Date effectiveToday = (today == null) ? Date.today() : today;
        TimeframeType type = parseTimeframeType(timeframeType);
        if (type == null) {
            throw new AuraHandledException('A valid timeframeType is required.');
        }

        if (type == LeadThroughputTimeframe.TimeframeType.QUARTER_YEAR) {
            if (quarterYearKeys == null || quarterYearKeys.isEmpty()) {
                throw new AuraHandledException('At least one Quarter+Year selection is required.');
            }
            // Hard guardrail: UI allows current year + prior 5 years => max 24 quarters.
            if (quarterYearKeys.size() > 24) {
                throw new AuraHandledException('Too many Quarter+Year selections. Please select 24 or fewer.');
            }
            return resolveQuarterYearDateWindows(quarterYearKeys);
        }

        return new List<DateWindow>{ resolveContiguousDateWindow(type, effectiveToday) };
    }

    public static DateWindow resolveContiguousDateWindow(TimeframeType type, Date today) {
        if (type == null) {
            throw new AuraHandledException('TimeframeType is required.');
        }
        Date startDate;
        Date endDate;

        switch on type {
            when YTD {
                startDate = Date.newInstance(today.year(), 1, 1);
                endDate = today;
            }
            when LAST_YEAR {
                Integer y = today.year() - 1;
                startDate = Date.newInstance(y, 1, 1);
                endDate = Date.newInstance(y, 12, 31);
            }
            when TWO_YEARS_AGO {
                Integer y = today.year() - 2;
                startDate = Date.newInstance(y, 1, 1);
                endDate = Date.newInstance(y, 12, 31);
            }
            when else {
                throw new AuraHandledException('Contiguous date window is not supported for timeframeType: ' + String.valueOf(type));
            }
        }

        return new DateWindow(startDate, endDate);
    }

    public static List<DateWindow> resolveQuarterYearDateWindows(List<String> quarterYearKeys) {
        Map<String, DateWindow> byKey = new Map<String, DateWindow>();
        for (String rawKey : quarterYearKeys) {
            String key = normalizeQuarterKey(rawKey);
            if (String.isBlank(key) || byKey.containsKey(key)) {
                continue;
            }
            byKey.put(key, parseQuarterKeyToWindow(key));
        }

        if (byKey.isEmpty()) {
            throw new AuraHandledException('At least one valid Quarter+Year selection is required.');
        }

        // Stable ordering for consistent query construction.
        List<String> keys = new List<String>(byKey.keySet());
        keys.sort();

        List<DateWindow> windows = new List<DateWindow>();
        for (String k : keys) {
            windows.add(byKey.get(k));
        }
        return windows;
    }

    public static List<CreatedDateWindow> toCreatedDateWindows(List<DateWindow> dateWindows) {
        List<CreatedDateWindow> windows = new List<CreatedDateWindow>();
        if (dateWindows == null) {
            return windows;
        }
        for (DateWindow w : dateWindows) {
            DateTime startInclusive = DateTime.newInstance(w.startDate, Time.newInstance(0, 0, 0, 0));
            DateTime endExclusive = DateTime.newInstance(w.endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
            windows.add(new CreatedDateWindow(startInclusive, endExclusive));
        }
        return windows;
    }

    private static String normalizeQuarterKey(String rawKey) {
        if (String.isBlank(rawKey)) {
            return null;
        }
        String v = rawKey.trim().toUpperCase();
        v = v.replace('_', '-');

        // Preferred: YYYY-Qn
        if (v.contains('-') && v.startsWith('20')) {
            return v;
        }

        // Tolerate: Qn YYYY
        if (v.startsWith('Q')) {
            List<String> parts = v.replace('-', ' ').split('\\s+');
            if (parts.size() >= 2) {
                String q = parts[0];
                String y = parts[1];
                return y + '-' + q;
            }
        }

        return v;
    }

    private static DateWindow parseQuarterKeyToWindow(String normalizedKey) {
        // Expected: YYYY-Qn
        List<String> parts = normalizedKey.split('-');
        if (parts.size() != 2) {
            throw new AuraHandledException('Invalid Quarter+Year value: ' + normalizedKey);
        }
        Integer year;
        try {
            year = Integer.valueOf(parts[0]);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid year in Quarter+Year value: ' + normalizedKey);
        }

        String qPart = parts[1];
        if (String.isBlank(qPart) || !qPart.startsWith('Q')) {
            throw new AuraHandledException('Invalid quarter in Quarter+Year value: ' + normalizedKey);
        }
        Integer quarter;
        try {
            quarter = Integer.valueOf(qPart.replace('Q', ''));
        } catch (Exception e) {
            throw new AuraHandledException('Invalid quarter in Quarter+Year value: ' + normalizedKey);
        }
        if (quarter < 1 || quarter > 4) {
            throw new AuraHandledException('Quarter must be 1-4 in Quarter+Year value: ' + normalizedKey);
        }

        Integer startMonth = ((quarter - 1) * 3) + 1;
        Integer endMonth = startMonth + 2;
        Date startDate = Date.newInstance(year, startMonth, 1);
        Integer lastDay = Date.daysInMonth(year, endMonth);
        Date endDate = Date.newInstance(year, endMonth, lastDay);
        return new DateWindow(startDate, endDate);
    }
}