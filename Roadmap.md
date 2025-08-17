Project Zonely

An app to help distributed teams connect better by showing name pronunciation, work hour overlaps, and holiday awareness.

Phase 1 — MVP (3–4 weeks)
	•	Backend:
	•	Basic user model (name, pronouns, role, timezone, country).
	•	Store phonetic spelling + audio recording/link.
	•	Store standard working hours.
	•	Frontend:
	•	Map/team list view.
	•	Profile hover cards with pronunciation.
	•	Timeline view to show overlapping working hours.
	•	Static holiday lookup (via 3rd-party API).
	•	Integrations:
	•	Basic holiday API (e.g., Nager.Date, Abstract API Holidays).

Phase 2 — Enhancements (4–6 weeks)
	•	Work hour overlap heatmap across entire team.
	•	Custom holiday/leave entries (not just public holidays).
	•	“Golden Hours” suggestions for meetings.
	•	Profile picture & personal links (LinkedIn, GitHub).

Phase 3 — Integrations & Polish
	•	Slack/Teams integration for quick lookup.
	•	Calendar sync for auto work hours.
	•	“Respect timezone” nudges before messaging.
	•	Exportable team directory.


Here’s a detailed dev prompt you can drop into Claude Code to bootstrap the implementation:

⸻

Prompt:

You are building a web app called Zonely, which helps distributed teams connect better by showing name pronunciation, work hour overlaps, and holiday awareness.

Please implement the MVP with the following specs:

Tech Stack
	•	Backend: Node.js (Express) or Python (FastAPI) – your choice.
	•	Frontend: React with TailwindCSS.
	•	Database: SQLite or Postgres (use Prisma ORM if Node.js).

Data Models
	1.	User
	•	id (UUID)
	•	name (string)
	•	phonetic (string, optional)
	•	pronunciation_audio_url (string, optional)
	•	pronouns (string, optional)
	•	role (string, optional)
	•	timezone (string, IANA format, e.g. “America/Los_Angeles”)
	•	country (string, ISO code)
	•	work_start (time, e.g. “09:00”)
	•	work_end (time, e.g. “17:00”)
	2.	Holiday
	•	id (UUID)
	•	country (string)
	•	date (date)
	•	name (string)

Features to Implement
	1.	Team Directory Page
	•	List all users with: name, pronouns, role, timezone, country flag.
	•	Hover over name → show profile card with pronunciation phonetic spelling and play button for audio.
	2.	Work Hour Overlap View
	•	Show a horizontal timeline for each teammate in their local timezone.
	•	Highlight overlapping working hours between selected teammates.
	3.	Holiday Awareness
	•	Fetch public holidays for each teammate’s country from Nager.Date API.
	•	Show upcoming holidays in their profile card and a “Holiday Dashboard.”

Stretch Goals (optional for later)
	•	“Golden Hour” calculation → suggest 2–3 best times for team meetings.
	•	Ability for teammates to add custom holidays/leave days.

Deliverables
	•	A single-page React app with navigation tabs:
	•	Directory (profiles + name pronunciation)
	•	Work Hours (timeline overlap)
	•	Holidays (team calendar view)
	•	REST API endpoints for users and holidays.
	•	Seed script with sample users (distributed across different countries & timezones).
	•	Seed script with sample users (distributed across different countries & timezones).
