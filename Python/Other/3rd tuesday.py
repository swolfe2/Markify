import calendar
import datetime

year = 2024

third_tuesdays = []
third_thursdays = []

for month in range(1, 13):
    # Get the calendar for the current month
    month_cal = calendar.monthcalendar(year, month)

    # Find the first Tuesday of the month
    first_tuesday = next(
        (
            day
            for week in month_cal
            for day in week
            if day != 0 and calendar.weekday(year, month, day) == calendar.TUESDAY
        ),
        None,
    )

    # If the first Tuesday was found, add 14 days to get the third Tuesday
    if first_tuesday is not None:
        third_tuesday = datetime.date(year, month, first_tuesday) + datetime.timedelta(
            days=14
        )
        third_tuesdays.append(third_tuesday.strftime("%m/%d/%Y"))

        # Add 2 days to get the third Thursday
        third_thursday = third_tuesday + datetime.timedelta(days=2)
        third_thursdays.append(third_thursday.strftime("%m/%d/%Y"))

# Print the list of third Tuesdays and third Thursdays
print(third_tuesdays)
print(third_thursdays)
