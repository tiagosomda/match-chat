#!/usr/bin/env python3
"""
Grant participant or admin status to a user.

Usage:
    python grant_participant.py <uid|email> [--invited-by <uid>] [--admin] [--dry-run]

The positional argument is treated as an email if it contains '@',
otherwise as a Firebase Auth UID.

Without --admin: sets isParticipant=true and invitedBy (defaults to "admin").
With --admin:    also sets isAdmin=true (implies participant as well).

It reads GOOGLE_APPLICATION_CREDENTIALS from the poller/.env file (or the
environment) to locate the Firebase service account.
"""

from __future__ import annotations

import argparse
import os
import sys

from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "poller/.env"))

import firebase_admin
from firebase_admin import credentials, firestore

_APP_PATH = ("match-chat", "app")
_USERS_COLLECTION = "users"

_POLLER_DIR = os.path.join(os.path.dirname(__file__), "poller")


def _init_app() -> None:
    if not firebase_admin._apps:
        sa_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "./service-account.json")
        # Resolve relative paths against the poller directory where the file lives.
        if not os.path.isabs(sa_path):
            sa_path = os.path.join(_POLLER_DIR, sa_path)
        cred = credentials.Certificate(sa_path)
        firebase_admin.initialize_app(cred)


def _firestore_client() -> firestore.Client:
    _init_app()
    return firestore.client()


def _resolve_user_ref(db: firestore.Client, uid_or_email: str):
    users_col = db.collection(_APP_PATH[0]).document(_APP_PATH[1]).collection(_USERS_COLLECTION)
    if "@" in uid_or_email:
        results = list(users_col.where("email", "==", uid_or_email).limit(1).stream())
        if not results:
            print(f"ERROR: No user found with email={uid_or_email!r}.", file=sys.stderr)
            sys.exit(1)
        return results[0].reference
    return users_col.document(uid_or_email)


def grant(uid_or_email: str, invited_by: str, make_admin: bool, dry_run: bool) -> None:
    db = _firestore_client()
    user_ref = _resolve_user_ref(db, uid_or_email)

    snap = user_ref.get()
    if not snap.exists:
        print(f"ERROR: No user document found for {uid_or_email!r}. Is the value correct?", file=sys.stderr)
        sys.exit(1)

    data = snap.to_dict() or {}
    print(f"User: {data.get('displayName', '(unknown)')} <{data.get('email', '')}>")
    print(f"  isParticipant (current): {data.get('isParticipant', False)}")
    print(f"  isAdmin       (current): {data.get('isAdmin', False)}")
    print(f"  invitedBy     (current): {data.get('invitedBy', None)}")
    print()

    update: dict = {}

    if not data.get("isParticipant") or not data.get("invitedBy"):
        update["isParticipant"] = True
        update["invitedBy"] = data.get("invitedBy") or invited_by

    if make_admin and not data.get("isAdmin"):
        update["isAdmin"] = True

    if not update:
        print("Nothing to change — user already has the requested permissions.")
        return

    if dry_run:
        print(f"[dry-run] Would update {user_ref.path} with: {update}")
        return

    user_ref.update(update)
    print(f"Done. Updated {user_ref.path}")
    for k, v in update.items():
        print(f"  {k} -> {v!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Grant participant or admin status to a user.")
    parser.add_argument("uid", help="Firebase Auth UID or email address of the user to promote")
    parser.add_argument(
        "--invited-by",
        default="admin",
        help="UID to record as the inviter (default: 'admin')",
    )
    parser.add_argument(
        "--admin",
        action="store_true",
        help="Also grant isAdmin=true",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would happen without writing to Firestore",
    )
    args = parser.parse_args()

    grant(uid_or_email=args.uid, invited_by=args.invited_by, make_admin=args.admin, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
