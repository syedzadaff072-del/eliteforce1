import os
from datetime import datetime

from flask import (
    Flask,
    render_template,
    request,
    redirect,
    url_for,
    session,
    flash
)

from flask_sqlalchemy import SQLAlchemy
from flask_socketio import SocketIO, emit, join_room
from werkzeug.security import generate_password_hash, check_password_hash


# =========================================================
# APP CONFIG
# =========================================================

app = Flask(__name__)

app.config["SECRET_KEY"] = os.environ.get(
    "SECRET_KEY",
    "elite-force-secret-key-change-this"
)

app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
    "DATABASE_URL",
    "sqlite:///elite_force.db"
)

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False


db = SQLAlchemy(app)

socketio = SocketIO(
    app,
    cors_allowed_origins="*"
)


# =========================================================
# ONLINE USERS
# =========================================================

# Socket ID -> User ID
online_sockets = {}


# =========================================================
# DATABASE MODELS
# =========================================================

class User(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    username = db.Column(
        db.String(80),
        unique=True,
        nullable=False
    )

    password_hash = db.Column(
        db.String(255),
        nullable=False
    )

    role = db.Column(
        db.String(20),
        default="member",
        nullable=False
    )

    approved = db.Column(
        db.Boolean,
        default=False,
        nullable=False
    )

    blocked = db.Column(
        db.Boolean,
        default=False,
        nullable=False
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )


class Message(db.Model):

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    username = db.Column(
        db.String(80),
        nullable=False
    )

    message = db.Column(
        db.Text,
        nullable=False
    )

    created_at = db.Column(
        db.DateTime,
        default=datetime.utcnow
    )


# =========================================================
# DATABASE + DEFAULT ADMIN
# =========================================================

with app.app_context():

    db.create_all()

    admin_username = os.environ.get(
        "ADMIN_USERNAME",
        "RazaAdmin"
    )

    admin_password = os.environ.get(
        "ADMIN_PASSWORD",
        "ChangeThisPassword123!"
    )

    existing_admin = User.query.filter_by(
        role="admin"
    ).first()

    if not existing_admin:

        admin = User(
            username=admin_username,
            password_hash=generate_password_hash(
                admin_password
            ),
            role="admin",
            approved=True,
            blocked=False
        )

        db.session.add(admin)
        db.session.commit()


# =========================================================
# HELPER FUNCTIONS
# =========================================================

def get_current_user():

    user_id = session.get("user_id")

    if not user_id:
        return None

    return db.session.get(
        User,
        user_id
    )


def is_approved_user():

    user = get_current_user()

    if not user:
        return False

    if user.blocked:
        return False

    if not user.approved:
        return False

    return True


def is_admin():

    user = get_current_user()

    if not user:
        return False

    return (
        user.role == "admin"
        and user.approved
        and not user.blocked
    )


def get_online_user_ids():

    return set(
        online_sockets.values()
    )


def get_presence_data():

    online_ids = get_online_user_ids()

    members = User.query.filter(
        User.approved == True,
        User.blocked == False
    ).order_by(
        User.role.desc(),
        User.username.asc()
    ).all()

    result = []

    for member in members:

        result.append(
            {
                "id": member.id,
                "username": member.username,
                "role": member.role,
                "online": member.id in online_ids
            }
        )

    return result


def broadcast_presence():
    """Broadcast online member status from HTTP routes or Socket.IO events."""
    socketio.emit(
        "presence_update",
        {
            "members": get_presence_data()
        },
        room="elite_force_chat"
    )


# =========================================================
# HOME
# =========================================================
@app.route("/sw.js")
def service_worker():
    response = app.send_static_file("sw.js")
    response.headers["Service-Worker-Allowed"] = "/"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["Content-Type"] = "application/javascript"
    return response


@app.route("/manifest.json")
def manifest():
    response = app.send_static_file("manifest.json")
    response.headers["Content-Type"] = "application/manifest+json"
    return response


@app.route("/favicon.ico")
def favicon():
    return app.send_static_file("favicon.ico")


@app.route("/")
def index():

    user = get_current_user()

    if user:

        if user.blocked:

            session.clear()

            flash(
                "Your account has been blocked."
            )

            return redirect(
                url_for("login")
            )

        if user.approved:

            if user.role == "admin":

                return redirect(
                    url_for("admin")
                )

            return redirect(
                url_for("chat")
            )

    return render_template(
        "index.html"
    )


# =========================================================
# REGISTER
# =========================================================

@app.route(
    "/register",
    methods=["GET", "POST"]
)
def register():

    if request.method == "POST":

        username = request.form.get(
            "username",
            ""
        ).strip()

        password = request.form.get(
            "password",
            ""
        )

        confirm_password = request.form.get(
            "confirm_password",
            ""
        )


        if not username or not password:

            flash(
                "Username and password are required."
            )

            return redirect(
                url_for("register")
            )


        if len(username) < 3:

            flash(
                "Username must be at least 3 characters."
            )

            return redirect(
                url_for("register")
            )


        if len(password) < 6:

            flash(
                "Password must be at least 6 characters."
            )

            return redirect(
                url_for("register")
            )


        if password != confirm_password:

            flash(
                "Passwords do not match."
            )

            return redirect(
                url_for("register")
            )


        existing_user = User.query.filter_by(
            username=username
        ).first()


        if existing_user:

            flash(
                "Username already exists."
            )

            return redirect(
                url_for("register")
            )


        new_user = User(
            username=username,
            password_hash=generate_password_hash(
                password
            ),
            role="member",
            approved=False,
            blocked=False
        )


        db.session.add(new_user)
        db.session.commit()


        flash(
            "Registration successful. Wait for Guild Leader approval."
        )

        return redirect(
            url_for("login")
        )


    return render_template(
        "register.html"
    )


# =========================================================
# LOGIN
# =========================================================

@app.route(
    "/login",
    methods=["GET", "POST"]
)
def login():

    if request.method == "POST":

        username = request.form.get(
            "username",
            ""
        ).strip()

        password = request.form.get(
            "password",
            ""
        )


        user = User.query.filter_by(
            username=username
        ).first()


        if not user:

            flash(
                "Invalid username or password."
            )

            return redirect(
                url_for("login")
            )


        if not check_password_hash(
            user.password_hash,
            password
        ):

            flash(
                "Invalid username or password."
            )

            return redirect(
                url_for("login")
            )


        if user.blocked:

            flash(
                "Your account has been blocked by the Guild Leader."
            )

            return redirect(
                url_for("login")
            )


        if not user.approved:

            flash(
                "Your account is waiting for Guild Leader approval."
            )

            return redirect(
                url_for("login")
            )


        session.clear()

        session["user_id"] = user.id


        if user.role == "admin":

            return redirect(
                url_for("admin")
            )


        return redirect(
            url_for("chat")
        )


    return render_template(
        "login.html"
    )


# =========================================================
# LOGOUT
# =========================================================

@app.route("/logout")
def logout():

    user = get_current_user()

    if user:

        # Remove all sockets belonging to this user
        sockets_to_remove = [
            sid
            for sid, uid in online_sockets.items()
            if uid == user.id
        ]

        for sid in sockets_to_remove:
            online_sockets.pop(
                sid,
                None
            )

    session.clear()

    return redirect(
        url_for("login")
    )


# =========================================================
# CHAT
# =========================================================

@app.route("/chat")
def chat():

    user = get_current_user()


    if not user:

        return redirect(
            url_for("login")
        )


    if user.blocked:

        session.clear()

        flash(
            "Your account has been blocked."
        )

        return redirect(
            url_for("login")
        )


    if not user.approved:

        flash(
            "Your account is waiting for approval."
        )

        return redirect(
            url_for("login")
        )


    # -----------------------------------------------------
    # APPROVED MEMBERS
    # -----------------------------------------------------

    members = User.query.filter(
        User.approved == True,
        User.blocked == False
    ).order_by(
        User.role.desc(),
        User.username.asc()
    ).all()


    # -----------------------------------------------------
    # LAST 100 MESSAGES
    # -----------------------------------------------------

    messages = Message.query.order_by(
        Message.created_at.desc()
    ).limit(100).all()


    # Reverse so oldest appears first
    messages.reverse()


    # Current online users
    online_ids = get_online_user_ids()


    return render_template(
        "chat.html",
        current_user=user,
        members=members,
        messages=messages,
        online_ids=online_ids
    )


# =========================================================
# ADMIN PANEL
# =========================================================

@app.route("/admin")
def admin():

    if not is_admin():

        flash(
            "Admin access required."
        )

        return redirect(
            url_for("login")
        )


    users = User.query.filter(
        User.role != "admin"
    ).order_by(
        User.created_at.desc()
    ).all()


    return render_template(
        "admin.html",
        users=users
    )


# =========================================================
# APPROVE MEMBER
# =========================================================

@app.route(
    "/admin/approve/<int:user_id>"
)
def approve_user(user_id):

    if not is_admin():

        return redirect(
            url_for("login")
        )


    user = db.session.get(
        User,
        user_id
    )


    if not user:

        flash(
            "Member not found."
        )

        return redirect(
            url_for("admin")
        )


    user.approved = True
    user.blocked = False

    db.session.commit()


    flash(
        f"{user.username} has been approved."
    )


    return redirect(
        url_for("admin")
    )


# =========================================================
# BLOCK MEMBER
# =========================================================

@app.route(
    "/admin/block/<int:user_id>"
)
def block_user(user_id):

    if not is_admin():

        return redirect(
            url_for("login")
        )


    user = db.session.get(
        User,
        user_id
    )


    if not user:

        flash(
            "Member not found."
        )

        return redirect(
            url_for("admin")
        )


    if user.role == "admin":

        flash(
            "You cannot block the Guild Leader."
        )

        return redirect(
            url_for("admin")
        )


    user.blocked = True
    user.approved = False

    db.session.commit()


    # Remove blocked member from online tracking
    sockets_to_remove = [
        sid
        for sid, uid in online_sockets.items()
        if uid == user.id
    ]

    for sid in sockets_to_remove:

        online_sockets.pop(
            sid,
            None
        )


    broadcast_presence()


    flash(
        f"{user.username} has been blocked."
    )


    return redirect(
        url_for("admin")
    )


# =========================================================
# REMOVE MEMBER
# =========================================================

@app.route(
    "/admin/remove/<int:user_id>"
)
def remove_user(user_id):

    if not is_admin():

        return redirect(
            url_for("login")
        )


    user = db.session.get(
        User,
        user_id
    )


    if not user:

        flash(
            "Member not found."
        )

        return redirect(
            url_for("admin")
        )


    if user.role == "admin":

        flash(
            "You cannot remove the Guild Leader."
        )

        return redirect(
            url_for("admin")
        )


    # Remove from online tracking
    sockets_to_remove = [
        sid
        for sid, uid in online_sockets.items()
        if uid == user.id
    ]

    for sid in sockets_to_remove:

        online_sockets.pop(
            sid,
            None
        )


    db.session.delete(user)

    db.session.commit()


    broadcast_presence()


    flash(
        "Member removed from ELITE FORCE."
    )


    return redirect(
        url_for("admin")
    )


# =========================================================
# SOCKET.IO — JOIN CHAT
# =========================================================

@socketio.on("join")
def handle_join():

    user = get_current_user()


    if not user:
        return


    if user.blocked:
        return


    if not user.approved:
        return


    join_room(
        "elite_force_chat"
    )


    # Save this browser/socket as online
    online_sockets[
        request.sid
    ] = user.id


    # Send current presence to everyone
    broadcast_presence()


# =========================================================
# SOCKET.IO — SEND MESSAGE
# =========================================================

@socketio.on("send_message")
def handle_message(data):

    user = get_current_user()


    if not user:
        return


    if user.blocked:
        return


    if not user.approved:
        return


    if not data:
        return


    message_text = str(
        data.get(
            "message",
            ""
        )
    ).strip()


    if not message_text:
        return


    # Maximum message length
    if len(message_text) > 1000:

        message_text = message_text[:1000]


    new_message = Message(
        username=user.username,
        message=message_text
    )


    db.session.add(
        new_message
    )

    db.session.commit()


    # Send message to everyone
    emit(
        "new_message",
        {
            "username": user.username,
            "message": message_text,
            "created_at": new_message.created_at.strftime(
                "%H:%M"
            ),
            "is_admin": user.role == "admin"
        },
        room="elite_force_chat"
    )


# =========================================================
# SOCKET.IO — DISCONNECT
# =========================================================

@socketio.on("disconnect")
def handle_disconnect():

    sid = request.sid


    if sid in online_sockets:

        online_sockets.pop(
            sid,
            None
        )


    # Update everyone
    broadcast_presence()


# =========================================================
# RUN SERVER
# =========================================================

if __name__ == "__main__":

    print("")
    print("======================================")
    print("        ELITE FORCE SERVER")
    print("======================================")
    print("")

    print(
        "Admin Username:",
        os.environ.get(
            "ADMIN_USERNAME",
            "RazaAdmin"
        )
    )

    print(
        "Open locally:",
        "http://127.0.0.1:5000"
    )

    print("")


    socketio.run(
        app,
        host=os.environ.get("HOST", "0.0.0.0"),
        port=int(os.environ.get("PORT", "5000")),
        debug=os.environ.get("FLASK_DEBUG", "0").lower() in ("1", "true", "yes"),
        allow_unsafe_werkzeug=True
    )