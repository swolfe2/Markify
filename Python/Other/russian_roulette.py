import random

# Print initial prompt
print("Enter a number between 1 and 10:")

while True:
    try:
        # Get user input and convert to integer
        guess = int(input())

        # Validate input is between 1 and 10
        if guess < 1 or guess > 10:
            print("Are you dumb? I said numbers between 1 and 10 only...")
            break

        # Generate random target number
        target = random.randint(1, 10)

        # Check guess against target
        if guess == target:
            print("You did it!")
            break
        else:
            print("Wrong, you dummy!")

    # Handle non-integer input
    except ValueError:
        print("Are you dumb? I said numbers between 1 and 10 only...")
        break
