from active_directory_automation_azure import main as active_directory
from tableau_portal_licenses_automation_azure import main as tableau_portal


def main():
    print("Get Active Directory information")
    active_directory()

    print("Get Tableau License information")
    tableau_portal()


if __name__ == "__main__":
    main()
