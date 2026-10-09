ELITE FORCE — Setup Guide
=========================

WINDOWS (LOCAL)
1. Install Python 3.11 or 3.12 from https://www.python.org/downloads/
   During installation, enable “Add Python to PATH”.
2. Extract this ZIP to a folder, for example Desktop\ELITE-FORCE.
3. Open Command Prompt in that folder.
4. Run: py -m venv venv
5. Run: venv\Scripts\activate
6. Run: python -m pip install --upgrade pip
7. Run: pip install -r requirements.txt
8. Run: python app.py
9. Open http://127.0.0.1:5000 in your browser.

DEFAULT ADMIN (change before public deployment)
Username: RazaAdmin
Password: ChangeThisPassword123!

The app reads ADMIN_USERNAME, ADMIN_PASSWORD, SECRET_KEY, PORT, HOST, and
FLASK_DEBUG from environment variables. Set a strong SECRET_KEY and a new
ADMIN_PASSWORD before putting the app on the public internet.

DEPLOYMENT NOTE
Procfile is included for platforms that support it. For a public deployment,
configure the environment variables above and use persistent storage or a
managed database so member accounts and chat history are not lost on redeploy.

RESPONSIVE / PWA
The pages include responsive layouts and PWA manifest/service-worker files.
Install availability depends on the browser and, for most browsers, HTTPS.
