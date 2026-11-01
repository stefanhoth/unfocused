#!/usr/bin/env python3
"""Fill an unfocused database with made-up Loops, People and Activity for screenshots.

Usage: demo-data.py <path/to/unfocused.sqlite> [--focused]

The database must already exist (the app creates it on first launch). Every row is
invented; nothing is read from the real database. --focused leaves one Loop Focused.
"""

import sqlite3
import sys
import time
import unicodedata
import uuid
from datetime import datetime, timedelta

path = sys.argv[1]
focused = "--focused" in sys.argv[2:]

now = datetime.now().replace(second=0, microsecond=0)
today = now.replace(hour=0, minute=0)


def ts(moment):
    return time.mktime(moment.timetuple())


def at(days_ago, hour, minute=0):
    return today - timedelta(days=days_ago) + timedelta(hours=hour, minutes=minute)


SLACK = "app:com.tinyspeck.slackmacgap"
MAIL = "app:com.apple.mail"

# The three Open Loops from the landing page's story, plus a few finished ones for the Recap.
VACATION_POLICY = "Vacation policy for the holidays"
loops = [
    {
        "title": "Q1 plan in Notion",
        "captured": at(6, 9, 30),
        "left_off": "Goals and the hiring section are written. The budget table still needs numbers from finance.",
        "anchors": [("chrome", "web:www.notion.so/acme/Q1-plan", "https://www.notion.so/acme/Q1-plan", "Q1 plan · Notion")],
        "people": [],
        "sessions": [(at(6, 10), 40)],
    },
    {
        "title": VACATION_POLICY,
        "captured": at(3, 11),
        "left_off": "Carry-over days are settled. Still open: who covers on-call between Christmas and New Year.",
        "anchors": [
            # Matches the local demo page the screenshots put in front, so the panel shows "You're here".
            ("chrome", "web:localhost/vacation-policy.html", "http://localhost:8765/vacation-policy.html", "Holiday vacation policy · Acme Docs"),
            (SLACK, "slack:acme/C02TEAM/1730300000.5678", "slack://channel?team=T01&id=C02TEAM", "#team · holidays thread"),
        ],
        "people": [("Lena Fischer", "owed")],
        "sessions": [(at(3, 11, 10), 35), (at(0, 10, 30), 25)],
    },
    {
        "title": "Review Sam's RFC",
        "captured": at(1, 14),
        "left_off": "Read up to section 4. Ask how the retry design handles offline edits.",
        "anchors": [("chrome", "web:github.com/acme/rfcs/pull/12", "https://github.com/acme/rfcs/pull/12", "RFC 012: Sync conflicts · Pull Request #12")],
        "people": [("Sam Okafor", "owed")],
        "sessions": [(at(1, 14, 5), 35)],
    },
    {
        "title": "Send the board update",
        "captured": at(2, 9),
        "state": ("closed", at(0, 9, 45)),
        "left_off": "Numbers are in. Only the hiring paragraph is missing.",
        "anchors": [(MAIL, "mail:<board-update@acme.example>", "message://%3Cboard-update@acme.example%3E", "Board update, October")],
        "people": [],
        "sessions": [(at(0, 9, 10), 30)],
    },
    {
        "title": "Learn Rust over the weekend",
        "captured": at(12, 20),
        "state": ("dropped", at(0, 8, 50)),
        "left_off": None,
        "anchors": [],
        "people": [],
        "sessions": [],
    },
]


def person_key(name):
    folded = unicodedata.normalize("NFKD", name)
    return "".join(c for c in folded if not unicodedata.combining(c)).lower()


db = sqlite3.connect(path)
cur = db.cursor()
for table in ["judgement", "activity", "involvement", "person", "anchor", "loopEvent", "focusSession", "loop"]:
    cur.execute(f"DELETE FROM {table}")

people = {}
for loop in loops:
    loop_id = str(uuid.uuid4()).upper()
    state, changed = loop.get("state", ("open", loop["captured"]))
    cur.execute(
        "INSERT INTO loop (id, title, state, capturedAt, whereILeftOff, stateChangedAt) VALUES (?, ?, ?, ?, ?, ?)",
        (loop_id, loop["title"], state, ts(loop["captured"]), loop["left_off"], ts(changed)),
    )
    cur.execute("INSERT INTO loopEvent (loopId, change, at) VALUES (?, 'captured', ?)", (loop_id, ts(loop["captured"])))
    if state != "open":
        cur.execute("INSERT INTO loopEvent (loopId, change, at) VALUES (?, ?, ?)", (loop_id, state, ts(changed)))
    for source, identifier, link, title in loop["anchors"]:
        cur.execute(
            "INSERT INTO anchor (loopId, source, identifier, link, title, addedAt) VALUES (?, ?, ?, ?, ?, ?)",
            (loop_id, source, identifier, link, title, ts(loop["captured"])),
        )
    for name, direction in loop["people"]:
        if name not in people:
            people[name] = str(uuid.uuid4()).upper()
            cur.execute("INSERT INTO person (id, name, key) VALUES (?, ?, ?)", (people[name], name, person_key(name)))
        cur.execute(
            "INSERT INTO involvement (loopId, personId, direction) VALUES (?, ?, ?)", (loop_id, people[name], direction)
        )
    for start, minutes in loop["sessions"]:
        end = start + timedelta(minutes=minutes)
        cur.execute("INSERT INTO focusSession (loopId, start, end) VALUES (?, ?, ?)", (loop_id, ts(start), ts(end)))
        # Time in the Loop's first Anchor while Focused, so the Recap and Activity have something to show.
        if loop["anchors"]:
            source, identifier, link, title = loop["anchors"][0]
            cur.execute(
                "INSERT INTO activity (source, identifier, link, title, start, lastSeen, closed) VALUES (?, ?, ?, ?, ?, ?, 1)",
                (source, identifier, link, title, ts(start), ts(end)),
            )
    loop["id"] = loop_id

# Unfocused time and active days: Slack and Mail checks, a news site, every day of the last two weeks.
for days_ago in range(13, -1, -1):
    for hour, minute, minutes, source, identifier, link, title in [
        (8, 40, 14, MAIL, "app:com.apple.mail|Inbox", "com.apple.mail", "Mail: Inbox"),
        (12, 15, 9, SLACK, "app:com.tinyspeck.slackmacgap|#general", "com.tinyspeck.slackmacgap", "Slack: #general"),
        (16, 5, 11, "chrome", "web:news.ycombinator.com", "https://news.ycombinator.com", "Hacker News"),
    ]:
        start = at(days_ago, hour, minute)
        if start > now:
            continue
        cur.execute(
            "INSERT INTO activity (source, identifier, link, title, start, lastSeen, closed) VALUES (?, ?, ?, ?, ?, ?, 1)",
            (source, identifier, link, title, ts(start), ts(start + timedelta(minutes=minutes))),
        )

if focused:
    focused_loop = next(loop for loop in loops if loop["title"] == VACATION_POLICY)
    cur.execute(
        "INSERT INTO focusSession (loopId, start, end) VALUES (?, ?, NULL)",
        (focused_loop["id"], ts(now - timedelta(minutes=25))),
    )
    source, identifier, link, title = focused_loop["anchors"][0]
    cur.execute(
        "INSERT INTO activity (source, identifier, link, title, start, lastSeen, closed) VALUES (?, ?, ?, ?, ?, ?, 0)",
        (source, identifier, link, title, ts(now - timedelta(minutes=25)), ts(now)),
    )

db.commit()
db.close()
print(f"Filled {path} with {len(loops)} Loops" + (", one Focused" if focused else ""))
