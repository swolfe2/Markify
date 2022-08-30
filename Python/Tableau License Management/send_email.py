import os
from datetime import datetime

import win32com.client as win32


def send_email(error_message, to_address, cc_address, process_step):
    """
    This subprocess will allow an email message to be sent,
    which will typically only be used for when something goes
    wrong in the process. It will always originate from the same source.

    Server name: smtp.office365.com
    Port: 587
    Encryption method: STARTTLS
    """

    def kill_outlook():
        """
        This subprocess will kill the Outlook applicaiton if currently open
        """
        win_management = win32.GetObject("winmgmts:")
        for process in win_management.ExecQuery(
            'select * from Win32_Process where Name="Outlook.exe"'
        ):
            # os.system("taskkill /pid /F /IM " + str(p.ProcessId))
            os.kill(process.ProcessId, 9)

    # Kill Outlook if it is currently open
    kill_outlook()

    # HTML email details
    html_body = (
        """
        Hello,
        <p>During today's run of the Python automation for Tableau Licesnses, the automation
        failed at the <span style="background-color: #FFFF00"><b>"""
        + process_step
        + """</b></span> step at """
        + datetime.now().strftime("%m/%d/%Y %H:%M")
        + """.</p>
        <p>The error message received by the program is:<br><i>"""
        + error_message
        + """</i>
        <p>Please perform a manual review, and correct any issues that may have occurred.</p>
        <p>Thank you,</p>"""
    )

    outlook_mail_item = 0x0
    obj = win32.Dispatch("Outlook.Application")
    new_mail = obj.CreateItem(outlook_mail_item)
    new_mail.Subject = "Tableau License Automation Failure: " + error_message
    new_mail.HTMLBody = html_body
    new_mail.To = to_address
    new_mail.Cc = cc_address
    new_mail.Send()
