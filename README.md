# Zonely

A web app that helps distributed teams connect better by showing name pronunciation, work hour overlaps, and holiday awareness.

## Features (MVP)

- **Team Directory**: View team members with pronunciation guides, roles, timezones, and countries
- **Work Hour Overlaps**: Visualize working hours across timezones and find optimal meeting times
- **Holiday Awareness**: Track public holidays across team locations with API integration

## Tech Stack

- **Backend**: Phoenix + LiveView (Elixir)
- **Database**: PostgreSQL with Ecto
- **Frontend**: TailwindCSS + Heroicons
- **API Integration**: Nager.Date for holiday data

## Getting Started

### Prerequisites

- Elixir 1.18+
- Phoenix Framework
- PostgreSQL

### Setup

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Create and migrate database:
   ```bash
   mix ecto.setup
   ```

3. Install npm dependencies:
   ```bash
   npm install --prefix assets
   ```

4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

5. Visit [`localhost:4000`](http://localhost:4000) to see the app

## Features

### Directory Page (`/`)
- Browse team members with profile cards
- Click on any member to see detailed pronunciation info
- View roles, timezones, pronouns, and working hours

### Work Hours Page (`/work-hours`)
- Select multiple team members to see working hour overlaps
- Visual timeline showing work hours in a 24-hour format
- "Golden Hours" suggestions for optimal meeting times

### Holidays Page (`/holidays`)
- Overview of team members by country
- Upcoming holidays with countdown
- Click "Refresh" to fetch latest holiday data from Nager.Date API
- Holiday impact dashboard

## Sample Data

The seed script creates 10 diverse team members across different:
- Countries: US, GB, JP, IN, SE, ES, AU, EG, BR
- Timezones: From Pacific to Tokyo
- Roles: Frontend, Backend, Product, DevOps, UX, etc.
- Working hours and pronunciation guides

## API Integration

Holiday data is fetched from the [Nager.Date API](https://date.nager.at/). Click the "Refresh" button on country cards to fetch current year holidays.

## Next Steps (Phase 2+)

- Enhanced timezone calculations with proper overlap detection
- Custom holiday/leave entries
- Slack/Teams integration
- Calendar sync for automatic work hours
- Audio pronunciation playback
- Profile pictures and social links