Show replacing of Geography table with Security Socio, and also renaming the column


# python
# Cursor Windows installer via Python: downloads the official installer and runs it silently

import os, sys, subprocess, urllib.request, ssl, tempfile

def is_admin():
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def main():
    # Enforce TLS 1.2
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS)
    ctx.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1

    # Official Windows installer URL
    url = "https://download.cursor.sh/windows/latest"  # resolves to latest signed installer
    out = os.path.join(tempfile.gettempdir(), "CursorSetup.exe")
    print(f"Downloading Cursor installer to: {out}")
    with urllib.request.urlopen(url, context=ctx) as r, open(out, "wb") as f:
        f.write(r.read())
    print("Download complete")

    # Silent install if supported, else interactive
    args = [out, "/S"]
    print("Starting installer...")
    try:
        proc = subprocess.run(args, check=False)
        if proc.returncode != 0:
            print("Silent mode failed, retrying interactively...")
            subprocess.run([out], check=False)
    except Exception as e:
        print(f"Installer error: {e}")
        print("Try running the exe manually or with admin privileges.")

    # Verify presence of cursor CLI
    try:
        subprocess.run(["cursor", "--version"], check=False)
        print("Cursor installed and on PATH.")
    except Exception:
        print("Cursor command not found. Log off and back on, or add the bin path to PATH:")
        print(r"  %APPDATA%\Local\        print(r"  %APPDATA%\Local\Programs\Cursor\resources\app\bin")

if __name__ == "__main__":
    print(f"Admin session: {is_admin()}")
