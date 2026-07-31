@IsTest
public class LeadThroughputTimeframeTest {

    @IsTest
    static void dateWindow_createsValidWindow() {
        Date startDate = Date.newInstance(2025, 1, 1);
        Date endDate = Date.newInstance(2025, 3, 31);

        LeadThroughputTimeframe.DateWindow w = new LeadThroughputTimeframe.DateWindow(startDate, endDate);

        System.assertEquals(startDate, w.startDate);
        System.assertEquals(endDate, w.endDate);
    }

    @IsTest
    static void createdDateWindow_createsValidWindow() {
        DateTime startInclusive = DateTime.newInstance(2025, 1, 1, 0, 0, 0);
        DateTime endExclusive = DateTime.newInstance(2025, 4, 1, 0, 0, 0);

        LeadThroughputTimeframe.CreatedDateWindow w = new LeadThroughputTimeframe.CreatedDateWindow(startInclusive, endExclusive);

        System.assertEquals(startInclusive, w.startInclusive);
        System.assertEquals(endExclusive, w.endExclusive);
    }

    @IsTest
    static void parseTimeframeType_returnsNullForBlank() {
        System.assertEquals(null, LeadThroughputTimeframe.parseTimeframeType(null));
        System.assertEquals(null, LeadThroughputTimeframe.parseTimeframeType(''));
        System.assertEquals(null, LeadThroughputTimeframe.parseTimeframeType('   '));
    }

    @IsTest
    static void parseTimeframeType_returnsNullForInvalid() {
        System.assertEquals(null, LeadThroughputTimeframe.parseTimeframeType('INVALID_TYPE'));
        System.assertEquals(null, LeadThroughputTimeframe.parseTimeframeType('NOT_A_TYPE'));
    }

    @IsTest
    static void parseTimeframeType_parsesValidTypes() {
        System.assertEquals(LeadThroughputTimeframe.TimeframeType.YTD, LeadThroughputTimeframe.parseTimeframeType('YTD'));
        System.assertEquals(LeadThroughputTimeframe.TimeframeType.YTD, LeadThroughputTimeframe.parseTimeframeType('ytd'));
        System.assertEquals(LeadThroughputTimeframe.TimeframeType.LAST_YEAR, LeadThroughputTimeframe.parseTimeframeType('LAST_YEAR'));
        System.assertEquals(LeadThroughputTimeframe.TimeframeType.TWO_YEARS_AGO, LeadThroughputTimeframe.parseTimeframeType('TWO_YEARS_AGO'));
        System.assertEquals(LeadThroughputTimeframe.TimeframeType.QUARTER_YEAR, LeadThroughputTimeframe.parseTimeframeType('QUARTER_YEAR'));
    }

    @IsTest
    static void resolveDateWindows_resolvesYTD() {
        Date today = Date.newInstance(2025, 6, 15);
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows('YTD', null, today);

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2025, 1, 1), windows[0].startDate);
        System.assertEquals(today, windows[0].endDate);
    }

    @IsTest
    static void resolveDateWindows_resolvesLastYear() {
        Date today = Date.newInstance(2025, 6, 15);
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows('LAST_YEAR', null, today);

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2024, 1, 1), windows[0].startDate);
        System.assertEquals(Date.newInstance(2024, 12, 31), windows[0].endDate);
    }

    @IsTest
    static void resolveDateWindows_resolvesTwoYearsAgo() {
        Date today = Date.newInstance(2025, 6, 15);
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows('TWO_YEARS_AGO', null, today);

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2023, 1, 1), windows[0].startDate);
        System.assertEquals(Date.newInstance(2023, 12, 31), windows[0].endDate);
    }

    @IsTest
    static void resolveDateWindows_resolvesQuarterYear() {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows('QUARTER_YEAR', new List<String>{ '2025-Q1', '2025-Q2' }, Date.today());

        System.assertEquals(2, windows.size());
        // Sorted by key
        System.assertEquals(Date.newInstance(2025, 1, 1), windows[0].startDate);
        System.assertEquals(Date.newInstance(2025, 3, 31), windows[0].endDate);
        System.assertEquals(Date.newInstance(2025, 4, 1), windows[1].startDate);
        System.assertEquals(Date.newInstance(2025, 6, 30), windows[1].endDate);
    }

    @IsTest
    static void resolveDateWindows_usesTodayWhenNull() {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows('YTD', null, null);

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(Date.today().year(), 1, 1), windows[0].startDate);
        System.assertEquals(Date.today(), windows[0].endDate);
    }

    @IsTest
    static void resolveQuarterYearDateWindows_deduplicatesKeys() {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveQuarterYearDateWindows(new List<String>{ '2025-Q1', '2025-Q1', '2025-Q1' });

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2025, 1, 1), windows[0].startDate);
    }

    @IsTest
    static void resolveQuarterYearDateWindows_parsesAlternateFormat() {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveQuarterYearDateWindows(new List<String>{ 'Q2 2025' });

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2025, 4, 1), windows[0].startDate);
        System.assertEquals(Date.newInstance(2025, 6, 30), windows[0].endDate);
    }

    @IsTest
    static void resolveQuarterYearDateWindows_parsesAllFourQuarters() {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveQuarterYearDateWindows(new List<String>{ '2025-Q1', '2025-Q2', '2025-Q3', '2025-Q4' });

        System.assertEquals(4, windows.size());

        System.assertEquals(Date.newInstance(2025, 1, 1), windows[0].startDate);
        System.assertEquals(Date.newInstance(2025, 3, 31), windows[0].endDate);

        System.assertEquals(Date.newInstance(2025, 4, 1), windows[1].startDate);
        System.assertEquals(Date.newInstance(2025, 6, 30), windows[1].endDate);

        System.assertEquals(Date.newInstance(2025, 7, 1), windows[2].startDate);
        System.assertEquals(Date.newInstance(2025, 9, 30), windows[2].endDate);

        System.assertEquals(Date.newInstance(2025, 10, 1), windows[3].startDate);
        System.assertEquals(Date.newInstance(2025, 12, 31), windows[3].endDate);
    }

    @IsTest
    static void toCreatedDateWindows_returnsEmptyForNull() {
        List<LeadThroughputTimeframe.CreatedDateWindow> result =
            LeadThroughputTimeframe.toCreatedDateWindows(null);

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void toCreatedDateWindows_convertsCorrectly() {
        List<LeadThroughputTimeframe.DateWindow> dateWindows = new List<LeadThroughputTimeframe.DateWindow>{
            new LeadThroughputTimeframe.DateWindow(Date.newInstance(2025, 1, 1), Date.newInstance(2025, 3, 31))
        };

        List<LeadThroughputTimeframe.CreatedDateWindow> result =
            LeadThroughputTimeframe.toCreatedDateWindows(dateWindows);

        System.assertEquals(1, result.size());
        System.assertEquals(DateTime.newInstance(2025, 1, 1, 0, 0, 0), result[0].startInclusive);
        System.assertEquals(DateTime.newInstance(2025, 4, 1, 0, 0, 0), result[0].endExclusive);
    }

    @IsTest
    static void parseQuarterKey_handlesUnderscoreFormat() {
        // Underscore should be converted to dash
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveQuarterYearDateWindows(new List<String>{ '2025_Q3' });

        System.assertEquals(1, windows.size());
        System.assertEquals(Date.newInstance(2025, 7, 1), windows[0].startDate);
    }
}