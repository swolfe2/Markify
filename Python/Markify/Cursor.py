
# python
# Cursor Windows installer via Python: downloads the official installer and runs silently

import os, subprocess, urllib.request, ssl, tempfile

def main():
    # Enforce TLS 1.2
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS)
    ctx.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1

    url = "https://download.cursor.sh/windows/latest"  # official endpoint
    out = os.path.join(tempfile.gettempdir(), "CursorSetup.exe")
    print(f"Downloading Cursor installer to: {out}")
    with urllib.request.urlopen(url, context=ctx) as r, open(out, "wb") as f:
        f.write(r.read())
    print("Download complete")

    # Silent install then verify
    print("Starting installer...")
    proc = subprocess.run([out, "/S"], check=False)
    if proc.returncode != 0:
        print("Silent mode failed, retrying interactively...")
        subprocess.run([out], check=False)

    # Verify CLI
    try:
        subprocess.run(["cursor", "--version"], check=True)
        print("Cursor installed and on PATH.")
    except Exception:
        print("Cursor not found on PATH. Add this to PATH or use the Command Palette in Cursor:")
        print(r"  %APPDATA%\Local\Programs\Cursor\resources\app\bin")

if __name__ == "__main__":
    main()
