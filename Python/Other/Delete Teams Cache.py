import os
import shutil
import subprocess


def main():

    username = os.environ.get("USERNAME")

    def close_teams():
        """This will close Microsoft Teams if open"""
        print("Closing Microsoft Teams if open...")
        subprocess.call("TASKKILL /F /IM teams.exe", shell=True)

    def delete_cached_files(username):
        "This will delete any files/folders from a the user's Microsoft Teams directory"

        folder = f"C:\\Users\\{username}\\AppData\\Roaming\\Microsoft\\Teams\\"

        print(f"Clearing folders and files from {folder}...")
        for filename in os.listdir(folder):
            file_path = os.path.join(folder, filename)
            try:
                if os.path.isfile(file_path) or os.path.islink(file_path):
                    os.unlink(file_path)
                elif os.path.isdir(file_path):
                    shutil.rmtree(file_path)
            except Exception as e:
                print("Failed to delete %s. Reason: %s" % (file_path, e))
        return

    def open_microsoft_teams(username):
        """This will reopen Microsoft Teams, and will not proceed until complete"""
        print("Opening Microsoft Teams...")
        folder = f"C:\\Users\\{username}\\AppData\\Local\\Microsoft\\Teams\\Current\\"
        subprocess.call((f"{folder}Teams.exe"))

    # Close Microsoft Teams if open
    close_teams()

    # Delete all folders and files from cache folder
    delete_cached_files(username)

    # Open Microsoft Teams once complete
    open_microsoft_teams(username)


if __name__ == "__main__":
    main()
