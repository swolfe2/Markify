import os
from datetime import datetime

import win32com.client as win32


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


def send_error_email(**kwargs):
    """
    This subprocess will allow an email message to be sent,
    which will typically only be used for when something goes
    wrong in the process. It will always originate from the same source.

    You will need to at least pass in a
    *error_message
    *process_step
    *to
    *cc (optional)
    *bcc (optional)

    Server name: smtp.office365.com
    Port: 587
    Encryption method: STARTTLS
    """

    # Kill Outlook if it is currently open
    kill_outlook()

    # HTML email details
    html_body = (
        """
        Hello,
        <p>During today's run of the Python automation for Tableau Licenses, the automation
        failed at the <span style="background-color: #FFFF00"><b>"""
        + kwargs["process_step"]
        + """</b></span> step at """
        + datetime.now().strftime("%m/%d/%Y %H:%M")
        + """(EST).</p>
        <p>The error message received by the program is:<br><i>"""
        + kwargs["error_message"]
        + """</i>
        <p>Please perform a manual review, and correct any issues that may have occurred.</p>
        <p>Thank you,</p>"""
    )

    outlook_mail_item = 0x0
    obj = win32.Dispatch("Outlook.Application")
    new_mail = obj.CreateItem(outlook_mail_item)
    new_mail.Subject = "Tableau License Automation Failure: " + kwargs["process_step"]
    new_mail.HTMLBody = html_body
    new_mail.To = kwargs["to"]
    if "cc" in kwargs:
        new_mail.Cc = kwargs["cc"]
    if "bcc" in kwargs:
        new_mail.Bcc = kwargs["bcc"]
    new_mail.Send()


def send_email(**kwargs):
    """
    This subprocess will allow an email message to be sent,
    which can be for any part of the process.

    You will need to at least pass in a
    *subject
    *html_body
    *to
    *cc (optional)
    *bcc (optional)

    Server name: smtp.office365.com
    Port: 587
    Encryption method: STARTTLS
    """

    # Kill Outlook if it is currently open
    kill_outlook()

    outlook_mail_item = 0x0
    obj = win32.Dispatch("Outlook.Application")
    new_mail = obj.CreateItem(outlook_mail_item)
    new_mail.Subject = kwargs["subject"]
    new_mail.HTMLBody = kwargs["html_body"]
    new_mail.To = kwargs["to"]

    if "cc" in kwargs:
        new_mail.Cc = kwargs["cc"]
    if "bcc" in kwargs:
        new_mail.Bcc = kwargs["bcc"]

    new_mail.Send()
