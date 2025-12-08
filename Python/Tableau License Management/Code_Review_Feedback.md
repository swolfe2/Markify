# Code Review & Improvement Roadmap

This document provides a summary of the code review for the Tableau License Management automation project. The feedback is intended to help build on the existing foundation, focusing on principles that enhance robustness, security, and maintainability.

---

### Area 1: Configuration & Secrets Management

This is the most critical area to address, as it involves security and makes your application much easier to manage.

*   **Problem:** The code contains hardcoded credentials, file paths, and server names directly within the scripts. This poses a security risk and makes it difficult to run the code in different environments (like moving from QA to production) without changing the code itself.
*   **Examples:**
    *   `utils/config.py` stores a password in plain text: `CRED_PW = "K1mberly!"`
    *   `yammer_azure.py` has a hardcoded bearer token: `token = "12467-RoGyPGy7Um0H3VrAFROcPA"`
    *   `active_directory_automation_azure.py` has a hardcoded file path: `file_path = r"\\kcfiles\share\Corporate\ITS\Application Solutions\Shared\Global HR Data"`
*   **How to Fix It:**
    1.  **Use a `.env` file for Local Development:** For ease of use, you can use a library like `python-dotenv`. Create a file named `.env` (and add it to your `.gitignore` so it's never committed) with your key-value pairs:
        ```ini
        # .env file
        TABLEAU_USERNAME="steve.wolfe@kcc.com"
        TABLEAU_PASSWORD="YourSecurePassword"
        YAMMER_TOKEN="YourYammerToken"
        AZURE_SERVER="your-server.database.windows.net"
        AD_FILE_PATH="//your/network/path"
        ```
    2.  **Load Configuration in Your Code:** Install the library (`pip install python-dotenv`) and load the variables in your script.
        ```python
        # In your main script, or a new config.py
        import os
        from dotenv import load_dotenv

        # This line loads variables from the .env file into the environment
        load_dotenv() 
        
        # Now you can access them securely throughout your application
        username = os.getenv("TABLEAU_USERNAME")
        password = os.getenv("TABLEAU_PASSWORD")
        ```
This approach cleanly separates your code from your configuration and is a standard industry practice.

---

### Area 2: Code Structure & Reusability (DRY Principle)

DRY stands for "Don't Repeat Yourself." Refactoring repetitive code makes your project much easier to maintain.

*   **Problem:** The `push_to_azure` function is defined in `active_directory_automation_azure.py`, `tableau_portal_licenses_automation_azure.py`, and `yammer_azure.py`. If you need to change how data is pushed to Azure, you have to update it in three different places.
*   **How to Fix It:**
    *   Create a single, more robust `push_df_to_azure` function inside `utils/azure_database.py`. This function can accept the dataframe, connection, temporary table name, and the final query or stored procedure to execute as parameters.

    ```python
    # In utils/azure_database.py
    def push_df_to_azure(df, conn, temp_table_name, final_stored_proc=None, final_query=None):
        """
        A centralized function to upload a DataFrame to a temporary table in Azure
        and then execute a final query or stored procedure.
        """
        # (Your existing logic for filling NAs, getting column types, etc.)
        outputdict = sqlcol(df)
        clean_dataframe(df)
        
        create_temp_table(df, conn, temp_table_name, outputdict)
        clean_temp_table(df, conn, temp_table_name)

        if final_stored_proc:
            execute_stored_procedure(conn, final_stored_proc)
        elif final_query:
            execute_query(conn, final_query)
            
        # (Your timing and logging logic)
    ```
Now, from your other scripts, you can simply import and call this one function, making your code much cleaner and easier to update.

---

### Area 3: Error Handling & Logging

Robust error handling is crucial for production systems. Your current method can be improved with more standard logging practices.

*   **Problem:** You use broad `try...except Exception:` blocks which can hide the specific type of error. You also manually call `send_error_email` and `sys.exit()` from many places. A centralized logging system is more standard and flexible.
*   **How to Fix It:**
    1.  **Use the `logging` Module:** Python's built-in `logging` module is the industry standard. You can configure it once to write to a file, the console, or even send emails for high-severity issues.

        ```python
        # At the start of your main full_process.py
        import logging

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            filename='tableau_automation.log' # This will create a log file
        )

        # In other files, get a logger instance
        import logging
        logger = logging.getLogger(__name__)

        try:
            # ... some operation ...
            logger.info("Successfully scraped Tableau data.")
        except Exception as e:
            # Log the full error with traceback
            logger.error(f"Failed to scrape Tableau data: {e}", exc_info=True)
            # The logger can be configured to send an email on ERROR level
            # This separates the "what happened" from the "how to notify"
            raise # Re-raise the exception to stop the process cleanly
        ```
    2.  **Catch Specific Exceptions:** Instead of `except Exception:`, try to catch more specific errors (e.g., `requests.exceptions.RequestException` for network issues, `KeyError` for dictionary access). This makes your code's behavior more predictable.

---

### Area 4: Dependency & Environment Management

This ensures that your application can be reliably installed and run on any machine.

*   **Problem:** The `requirements.txt` file lists all packages, including dependencies of your main packages. This makes it hard to know what the direct requirements are.
*   **How to Fix It:**
    1.  **Use a Virtual Environment:** Always develop in a virtual environment to isolate your project's dependencies.
        ```bash
        # Create a virtual environment in your project folder
        python -m venv .venv

        # Activate it (on Windows)
        .venv\Scripts\activate
        ```
    2.  **Curate `requirements.txt`:** Your `requirements.txt` should ideally only contain the top-level packages you directly `import`. For this project, a cleaner file would look like this:
        ```
        # requirements.txt
        pandas
        playwright
        pywin32
        turbodbc
        azure-identity
        azure-keyvault-secrets
        python-dotenv
        requests
        sqlalchemy
        ```
When you run `pip install -r requirements.txt`, pip will automatically handle installing the necessary sub-dependencies.

---

### Area 5: Database & Pandas Interaction

You can make your interactions with your data more efficient and much safer.

*   **Problem:** You build SQL queries using basic string concatenation/replacement (the `sql_char_to_replace` dictionary in `azure_database.py`), which is vulnerable to SQL Injection and is very brittle.
*   **How to Fix It:**
    1.  **Use Parameterized Queries:** Database drivers have a built-in, safe way to pass parameters into queries. `turbodbc` uses `?` as a placeholder. The driver handles all the necessary quoting and escaping to prevent attacks.

        ```python
        # Instead of this error-prone method:
        # unsafe_value = "O'Malley"
        # query = f"UPDATE my_table SET name = '{unsafe_value}'"

        # Do this:
        safe_value = "O'Malley"
        query = "UPDATE my_table SET name = ? WHERE id = ?"
        # The driver handles the value safely
        cursor.execute(query, safe_value, 123)
        ```
    2.  **Leverage SQLAlchemy for Inserts:** You are already using `sqlalchemy`. Its `to_sql` method is highly optimized for bulk inserts and is much safer and more efficient than building `INSERT` statements manually.
        ```python
        import sqlalchemy

        # Create an engine from your connection details
        engine = sqlalchemy.create_engine("mssql+pyodbc://...", fast_executemany=True)

        # This one line can replace most of your create_temp_table function
        df.to_sql(
            name=temp_table_name, 
            con=engine, 
            if_exists='replace', # or 'append'
            index=False
        )
        ```
---

### Conclusion

You have successfully built a working automation system that provides real value. By focusing on these areas, you can elevate your project to be more secure, robust, and professional—making it easier for you and others to maintain and improve in the future.
