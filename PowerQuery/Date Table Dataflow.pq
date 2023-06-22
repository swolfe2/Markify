let
    // Today's date
    Today = Date.From(DateTime.LocalNow()),
    // Set the start year of the date dimension. Dates start from 1st of January of year.
    FromYear = Date.Year(Today) - 10,
    // Set the end year for the date dimension.
    ToYear = Date.Year(Today) + 10,
    // Table configuration
    FromDate = #date(FromYear, 1, 1),
    ToDate = #date(ToYear, 12, 31),
    Source = List.Dates(FromDate, Duration.Days(ToDate - FromDate) + 1, #duration(1, 0, 0, 0)),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    // Date functions
    #"Rename Date Column" = Table.RenameColumns(#"Converted to Table", {{"Column1", "Date"}}),
    #"Changed Date Column Type" = Table.TransformColumnTypes(#"Rename Date Column", {{"Date", type date}}),
    #"Year-Month-Date" = Table.AddColumn(
        #"Changed Date Column Type", "Year-Month-Date", each Number.From(Date.ToText([Date], "yyyyMMdd")), Int64.Type
    ),
    #"Month-Date-Year" = Table.AddColumn(
        #"Year-Month-Date", "Month-Date-Year", each Number.From(Date.ToText([Date], "MMddyyyy")), Int64.Type
    ),
    #"Date-Month-Year" = Table.AddColumn(
        #"Month-Date-Year", "Date-Month-Year", each Number.From(Date.ToText([Date], "ddMMyyyy")), Int64.Type
    ),
    #"Year 2-Month-Date" = Table.AddColumn(
        #"Date-Month-Year", "Year 2-Month-Date", each Number.From(Date.ToText([Date], "yyMMdd")), Int64.Type
    ),
    #"Month-Date-Year 2" = Table.AddColumn(
        #"Year 2-Month-Date", "Month-Date-Year 2", each Number.From(Date.ToText([Date], "MMddyy")), Int64.Type
    ),
    #"Date-Month-Year 2" = Table.AddColumn(
        #"Month-Date-Year 2", "Date-Month-Year 2", each Number.From(Date.ToText([Date], "ddMMyy")), Int64.Type
    ),
    #"Before Today" = Table.AddColumn(
        #"Date-Month-Year 2", "Before Today", each if [Date] < Today then "Yes" else "No", type text
    ),
    // Year Functions
    #"Year" = Table.AddColumn(#"Before Today", "Year", each Date.Year([Date]), Int64.Type),
    #"Year 2" = Table.AddColumn(#"Year", "Year 2", each Number.From(Date.ToText([Date], "yy")), Int64.Type),
    #"Start of Year" = Table.AddColumn(#"Year 2", "Start of Year", each Date.StartOfYear([Date]), type date),
    #"End of Year" = Table.AddColumn(#"Start of Year", "End of Year", each Date.EndOfYear([Date]), type date),
    #"Days in Year" = Table.TransformColumnTypes(
        Table.AddColumn(#"End of Year", "Days in Year", each Duration.Days([End of Year] - [Start of Year]) + 1),
        {{"Days in Year", Int64.Type}}
    ),
    #"Year Offset" = Table.AddColumn(#"Days in Year", "Year Offset", each ([Year] - Date.Year(Today)), Int64.Type),
    // Month functions
    #"Month" = Table.AddColumn(#"Year Offset", "Month", each Date.Month([Date]), Int64.Type),
    #"Month Name" = Table.AddColumn(#"Month", "Month Name", each Date.MonthName([Date]), type text),
    #"Mon Name" = Table.AddColumn(#"Month Name", "Mon Name", each Date.ToText([Date], "MMM"), type text),
    #"Start of Month" = Table.AddColumn(#"Mon Name", "Start of Month", each Date.StartOfMonth([Date]), type date),
    #"End of Month" = Table.AddColumn(#"Start of Month", "End of Month", each Date.EndOfMonth([Date]), type date),
    #"Days in Month" = Table.AddColumn(#"End of Month", "Days in Month", each Date.DaysInMonth([Date]), Int64.Type),
    #"Month Offset" = Table.AddColumn(
        #"Days in Month",
        "Month Offset",
        each (([Year] - Date.Year(Today)) * 12) + ([Month] - Date.Month(Today)),
        Int64.Type
    ),
    #"Month Year 2" = Table.AddColumn(
        #"Month Offset", "Month Year 2", each Date.ToText([Date], "MMMMM yy"), type text
    ),
    #"Month Year 4" = Table.AddColumn(
        #"Month Year 2", "Month Year 4", each Date.ToText([Date], "MMMMM yyyy"), type text
    ),
    #"Mon Year 2" = Table.AddColumn(#"Month Year 4", "Mon Year 2", each Date.ToText([Date], "MMM yy"), type text),
    #"Mon Year 4" = Table.AddColumn(#"Mon Year 2", "Mon Year 4", each Date.ToText([Date], "MMM yyyy"), type text),
    #"M Year 2" = Table.AddColumn(#"Mon Year 4", "M Year 2", each Date.ToText([Date], "M yy"), type text),
    #"M Year 4" = Table.AddColumn(#"M Year 2", "M Year 4", each Date.ToText([Date], "M yyyy"), type text),
    #"Month-Year" = Table.AddColumn(
        #"M Year 4", "Month-Year", each Number.From(Date.ToText([Date], "MMyyyy")), Int64.Type
    ),
    #"Year-Month" = Table.AddColumn(
        #"Month-Year", "Year-Month", each Number.From(Date.ToText([Date], "yyyyMM")), Int64.Type
    ),
    //Quarter functions
    #"Quarter" = Table.AddColumn(#"Year-Month", "Quarter", each Date.QuarterOfYear([Date]), Int64.Type),
    #"Q" = Table.AddColumn(#"Quarter", "Q", each "Q" & Text.From([Quarter]), type text),
    #"Q Year 2" = Table.AddColumn(
        #"Q", "Q Year 2", each "Q" & Text.From([Quarter]) & " " & Text.From([Year 2]), type text
    ),
    #"Q Year 4" = Table.AddColumn(
        #"Q Year 2", "Q Year 4", each "Q" & Text.From([Quarter]) & " " & Text.From([Year]), type text
    ),
    #"Start of Quarter" = Table.AddColumn(
        #"Q Year 4", "Start of Quarter", each Date.StartOfQuarter([Date]), type date
    ),
    #"End of Quarter" = Table.AddColumn(
        #"Start of Quarter", "End of Quarter", each Date.EndOfQuarter([Date]), type date
    ),
    #"Days in Quarter" = Table.TransformColumnTypes(
        Table.AddColumn(
            #"End of Quarter", "Days in Quarter", each Duration.Days([End of Quarter] - [Start of Quarter]) + 1
        ),
        {{"Days in Quarter", Int64.Type}}
    ),
    #"Quarter Offset" = Table.AddColumn(
        #"Days in Quarter",
        "Quarter Offset",
        each (([Year] - Date.Year(Today)) * 4) + ([Quarter] - Date.QuarterOfYear(Today)),
        Int64.Type
    ),
    // Week functions
    #"Week of Year - Sunday" = Table.AddColumn(
        #"Quarter Offset", "Week of Year - Sunday", each Date.WeekOfYear([Date], Day.Sunday), Int64.Type
    ),
    #"Week of Month - Sunday" = Table.AddColumn(
        #"Week of Year - Sunday", "Week of Month - Sunday", each Date.WeekOfMonth([Date], Day.Sunday), Int64.Type
    ),
    #"Start of Week - Sunday" = Table.AddColumn(
        #"Week of Month - Sunday", "Start of Week - Sunday", each Date.StartOfWeek([Date], Day.Sunday), type date
    ),
    #"End of Week - Sunday" = Table.AddColumn(
        #"Start of Week - Sunday", "End of Week - Sunday", each Date.EndOfWeek([Date], Day.Sunday), type date
    ),
    #"Week Offset - Sunday" = Table.AddColumn(
        #"End of Week - Sunday",
        "Week Offset - Sunday",
        each Number.RoundDown(Duration.Days(Today - [#"Start of Week - Sunday"]) / 7),
        Int64.Type
    ),
    #"Week of Year - Monday" = Table.AddColumn(
        #"Week Offset - Sunday", "Week of Year - Monday", each Date.WeekOfYear([Date], Day.Monday), Int64.Type
    ),
    #"Week of Month - Monday" = Table.AddColumn(
        #"Week of Year - Monday", "Week of Month - Monday", each Date.WeekOfMonth([Date], Day.Monday), Int64.Type
    ),
    #"Start of Week - Monday" = Table.AddColumn(
        #"Week of Month - Monday", "Start of Week - Monday", each Date.StartOfWeek([Date], Day.Monday), type date
    ),
    #"End of Week - Monday" = Table.AddColumn(
        #"Start of Week - Monday", "End of Week - Monday", each Date.EndOfWeek([Date], Day.Monday), type date
    ),
    #"Week Offset - Monday" = Table.AddColumn(
        #"End of Week - Monday",
        "Week Offset - Monday",
        each Number.RoundDown(Duration.Days(Today - [#"Start of Week - Monday"]) / 7),
        Int64.Type
    ),
    // Day functions
    #"Day" = Table.AddColumn(#"Week Offset - Monday", "Day", each Date.Day([Date]), Int64.Type),
    #"Day Name" = Table.AddColumn(#"Day", "Day Name", each Date.DayOfWeekName([Date]), type text),
    #"Day Name 3" = Table.AddColumn(
        #"Day Name", "Day Name 3", each Text.Replace(Text.Start([Day Name], 3), "Thu", "Thr"), type text
    ),
    #"Day of Week - Sunday" = Table.AddColumn(
        #"Day Name 3", "Day of Week - Sunday", each Date.DayOfWeek([Date], Day.Sunday) + 1, Int64.Type
    ),
    #"Day of Week - Monday" = Table.AddColumn(
        #"Day of Week - Sunday", "Day of Week - Monday", each Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type
    ),
    #"Day Offset" = Table.AddColumn(
        #"Day of Week - Monday", "Day Offset", each Duration.Days([Date] - Today), Int64.Type
    )
in
    #"Day Offset"
