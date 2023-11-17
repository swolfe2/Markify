let
  func = 
    let
      fn_Workday = (inputDate as date, inputMonthOffset as number, inputBusinessDayOffset as number) =>
        let
          //Get the month offset value from inputMonthOffset
          DateWithMonthOffset = Date.AddMonths(inputDate, inputMonthOffset),
          //Get the first day of the month from the inputMonthOffset
          FirstDayOfMonth = Date.StartOfMonth(DateWithMonthOffset),
          //Get a list of all Monday - Friday dates
          BusinessDays = List.Select(
            List.Dates(
              FirstDayOfMonth,
              Date.DaysInMonth(DateWithMonthOffset),
              #duration(1, 0, 0, 0)
            ),
            each Date.DayOfWeek(_) <> Day.Saturday and Date.DayOfWeek(_) <> Day.Sunday
          ),
          //Ensure the list is sorted in ascending order
          SortedBusinessDays = List.Sort(BusinessDays),
          //Get the index 0 based position from the inputBusinessDayOffset
          BusinessDayPosition = SortedBusinessDays{inputBusinessDayOffset - 1},
          //Get the date/time value of the BusinessDayPosition
          BusinessDayPositionWithDateTime = DateTime.From(BusinessDayPosition)
        in
          BusinessDayPositionWithDateTime
    in
      fn_Workday,
  documentation = [
    Documentation.Name = " WORKDAY ",
    Documentation.Description
      = "This function will return the business day position from the month offset based on a reference date.",
    Documentation.LongDescription
      = "This function will return the business day position from the month offset based on a reference date.",
    Documentation.Category = " Nth Business Day ",
    Documentation.Version = " 1.0 ",
    Documentation.Author = " Steve Wolfe ",
    Documentation.Examples = {
      [
        Description = "  ",
        Code        = " fn_Workday(#date(2023, 11, 15), 0, 8)",
        Result      = " 11/10/2023 12:00:00 AM"
      ]
    }
  ]
in
  Value.ReplaceType(func, Value.ReplaceMetadata(Value.Type(func), documentation))
