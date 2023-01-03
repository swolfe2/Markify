import calendar

year = 2023
month = 1

while month < 13:
    # Get the calendar for the current month
    month_cal = calendar.monthcalendar(year, month)

    # Get the third Tuesday of the month
    third_tuesday = month_cal[3][calendar.TUESDAY]

    print(third_tuesday)

    month = month + 1
