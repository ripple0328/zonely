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
	•	"Respect timezone" nudges before messaging.
	•	Exportable team directory.

Phase 4 — Live & Interactive Features (LiveView-Powered)
	•	**Real-Time Overlap Heatmap**
		•	Dynamic, live-updating heatmap of global working hours overlap.
		•	Interactive hover functionality: select time blocks to instantly highlight who is "green" (working), "yellow" (winding down), "red" (asleep).
		•	Push updates to all connected clients as people change schedules or mark OOO status.
	•	**Meeting Time Negotiator (Collaborative Voting)**
		•	Multi-teammate selection → instant shared availability grid.
		•	Real-time collaborative voting/drag-select for preferred time slots.
		•	Live avatar indicators showing teammate selections as they happen.
		•	Multiplayer scheduling experience with low-latency updates.
	•	**Presence-Aware Map**
		•	Integration with Slack/Teams presence status.
		•	Live avatar states: pulsing green (active), faded (idle), grey (offline).
		•	Hover tooltips showing last activity timestamps.
		•	Phoenix Presence integration for scalable real-time tracking.
	•	**Contextual Day/Night Storyline**
		•	Animated "world clock in motion" showing global workday flow.
		•	Smooth avatar transitions between work/personal/sleep phases.
		•	Watch the "wave" of workday sweep across the globe in real-time.
		•	Efficient state synchronization for lag-free global animation.
	•	**Seamless Inline Actions**
		•	Direct map popup actions: "Propose meeting time" → instant invite.
		•	Integrated shortcuts: "Ping in Slack/Email" without leaving the map.
		•	Immediate action execution via LiveView events.

🔑 **Key Differentiator**: Transform from static reference tool into living, multiplayer coordination hub with real-time presence, collaborative scheduling, and time-overlap visualization.

⸻

## 🎯 Collaborative Meeting Negotiator - Detailed UX Flow & MVP

### Goal
Make it dead simple for distributed teammates to find overlapping time and agree on a meeting slot — in real-time, powered by Phoenix LiveView + Presence.

### 🔄 UX Flow

**Step 1: Select Teammates**
- User clicks multiple avatars on the map (e.g., Ahmed in Cairo, Maria in Madrid, Zoe in LA).
- A "Meeting Planner" side panel slides in.
- Panel shows selected teammates with avatars + timezones.

**Step 2: Overlap Grid Appears**
- LiveView renders a 24-hour timeline grid, aligned to the organizer's timezone.
- Each teammate's working hours are highlighted in green bars on the grid.
- Overlaps are automatically shaded in darker green zones.
- Outside working hours are greyed.

*(Think: "Google Calendar's 'Find a Time'" but visual + global.)*

**Step 3: Real-Time Voting**
- Organizer hovers over a time range (say, 9–10 AM PDT).
- LiveView broadcasts → teammates see a live hover highlight in their local timezone row.
- Teammates can click to vote ("👍 works for me") or "👎 can't do it."
- Votes appear instantly: tiny avatar dots show up under the slot.
- If someone leaves the panel open, they can literally watch others' votes roll in live.

**Step 4: Negotiation Helpers**
- If no perfect overlap exists, app suggests best compromise slots ranked by:
  - \# of people within working hours
  - % of people who voted yes
  - Least timezone pain (nobody at 3 AM)
- These suggestions update in real-time as people vote.

**Step 5: Lock It In**
- Once enough votes are in (or the organizer decides), they click "Confirm Slot".
- LiveView instantly:
  - Sends a summary card to all selected teammates ("Meeting confirmed: Thu Aug 22, 9–10 AM PDT / 7–8 PM EET / 8–9 PM MSK").
  - Provides one-click "Add to Calendar" links (Google, Outlook, ICS).

### ⚡ Why This Is Killer in LiveView
- **Instant feedback** → No "refresh page" or "send Doodle link." Everyone sees the same live state.
- **Presence integration** → You know who's actually online and responding.
- **Lightweight scaling** → Phoenix Presence can track 1000s of participants without extra infra.
- **Single-page flow** → Everything happens inline on the map, no switching tools.

### 🖼️ Example UI (Text Wireframe)
```
-----------------------------------------
Meeting Planner (3 selected)

 🕒 Timezone alignment: PDT (Los Angeles)

 Grid:
   LA   | ████████─────── (9AM–5PM)
   Madrid| ───███████──── (9AM–5PM)
   Cairo | ─────███────── (9AM–5PM)

 Overlaps:
   9–10 AM PDT → ✅ Zoe, ❌ Maria, ✅ Ahmed
   3–4 PM PDT → ✅ Zoe, ✅ Maria, ✅ Ahmed

 [Suggest Best Time: 3–4 PM PDT]
-----------------------------------------
```

### 🛠️ Phase-1 MVP Breakdown (Phoenix + LiveView)

**1. Foundations**
- **Data models:**
  - User: name, avatar, timezone, working_hours_start, working_hours_end
  - Meeting: creator_id, participant_ids, proposed_slots, confirmed_slot
  - Vote: meeting_id, user_id, slot_id, vote (yes/no)
- **LiveView setup:**
  - `/meeting_planner` LiveView for the feature.
  - Leverage Phoenix Presence to track who's currently viewing the planner.

**2. Core UX Flow MVP**

*Step 1: Select Teammates*
- Map view → user clicks avatars.
- Minimal: just a checkbox list of participants (from Presence or Org DB).
- On submit, opens `/meeting_planner/:meeting_id`.

*Step 2: Show Overlap Grid*
- LiveView renders:
  - X-axis = 24 hours in organizer's timezone.
  - Y-axis = rows for each participant.
  - Highlight green blocks = working hours.
  - Grey out non-working hours.

*(Basic SVG or Tailwind flex grid for rendering; keep simple in MVP.)*

*Step 3: Real-Time Voting*
- Hovering → LiveView phx-click pushes a "propose slot" event.
- All connected participants see a live highlight (assigns updated via PubSub).
- Clicking a slot → creates a Vote.
- Slot shows tiny avatar chips for who voted yes/no.
- Minimal UI = ✅/❌ count under each slot.

*Step 4: Simple Suggestion*
- MVP suggestion = "slot with highest # of yes votes."
- Later: smarter ranking (timezones pain index, compromise score).

*Step 5: Confirm Slot*
- Organizer clicks "Confirm."
- Meeting record gets confirmed_slot.
- Everyone in LiveView sees:
  - "Meeting Confirmed: Aug 22, 9–10 AM PDT / 7–8 PM EET."
  - Provide ICS download link (generated via Elixir lib icalendar).

**3. Technical Leverage of Phoenix/LiveView**
- **Live collaboration:** Votes and slot highlights sync instantly across all participants.
- **Presence:** Show who's "in the planner" right now.
- **PubSub scaling:** Efficiently broadcast to all viewers without overloading backend.
- **Single-page interactivity:** No React/SPA needed; LiveView handles everything.

**4. Stretch Goals (Phase 2+)**
- Avatar dots on slots (instead of just counts).
- Drag-select multi-hour ranges.
- Integrate Slack/Teams presence (OOO detection).
- Smart suggestions (weighted by timezone fairness).
- Calendar API integration (Google/Outlook free/busy sync).

**✅ Phase-1 Success Criteria:**
- Can select teammates
- See overlap grid (with working hours)
- Propose a slot → others see it live
- Vote → votes update live
- Organizer confirms → ICS file downloadable

*That's enough to wow users and showcase LiveView's strength in multiplayer coordination.*

⸻

Here's a detailed dev prompt you can drop into Claude Code to bootstrap the implementation:

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
