import os
import shutil
import time

start_time = time.time()

# Set source and target folders
source_folder = r"\\KCFiles\Share\Corporate\DataVizSupport"
secure_name = "Secured PBIX Files Support Team Access Only"
target_folder = os.path.join(source_folder, secure_name)


# Process source folders
def process_folders(src_folders):
    """Moves qualifying folders from source to target.
    Returns count of folders moved."""

    folders_moved = 0

    for d in src_folders:
        # Construct full source and destination paths
        src_dir = os.path.join(source_folder, d)
        dst_dir = os.path.join(target_folder, d)

        # Check if folder meets criteria for moving
        if should_move(src_dir):
            # Move folder to target
            move(src_dir, dst_dir)

            # Increment counter
            folders_moved += 1

    return folders_moved


# Process source files
def process_files(src_files):
    """Moves qualifying files from source to target.
    Returns count of files moved."""

    files_moved = 0

    for f in src_files:
        # Construct full paths
        src_file = os.path.join(source_folder, f)
        dst_file = os.path.join(target_folder, f)

        # Check if file should move
        if should_move(src_file):
            # Move file to target
            move(src_file, dst_file)

            # Increment counter
            files_moved += 1

    return files_moved


# Check if item meets criteria for moving
def should_move(src):
    """Checks if source item meets criteria for moving.
    Currently checks if MODIFIED in last 24 hrs."""

    if os.stat(src).st_mtime > time.time() - 86400:
        return True
    return False


# Move item from source to target
def move(src, dst):
    """Moves source item to destination.
    Overwrites existing target item if present."""

    if os.path.exists(dst):
        if os.path.isfile(dst):
            os.remove(dst)
        elif os.path.isdir(dst):
            shutil.rmtree(dst)

    shutil.move(src, dst)


# Main program function
def main():
    """Main program function.
    Gets source items, processes them, prints results."""

    # Get list of source folders
    src_folders = [
        d
        for d in os.listdir(source_folder)
        if os.path.isdir(os.path.join(source_folder, d))
    ]

    # Remove target folder from list if present
    if secure_name in src_folders:
        src_folders.remove(secure_name)

    # Get list of source files
    src_files = [
        f
        for f in os.listdir(source_folder)
        if os.path.isfile(os.path.join(source_folder, f))
    ]

    # Process source folders
    folders_moved = process_folders(src_folders)

    # Process source files
    files_moved = process_files(src_files)

    # Calculate total runtime
    end_time = time.time()
    run_time = end_time - start_time

    # Print results
    print(f"{folders_moved} folder(s) moved.")
    print(f"{files_moved} files(s) moved.")
    print(f"Total script run time: {run_time:.2f} seconds")


if __name__ == "__main__":
    main()
