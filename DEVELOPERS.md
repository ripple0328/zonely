# Developer Documentation

This guide covers technical setup, development workflow, and architecture details for Zonely.

## Tech Stack

- **Backend**: Phoenix + LiveView (Elixir 1.18+)
- **Database**: PostgreSQL with Ecto
- **Frontend**: TailwindCSS + Heroicons
- **Real-time**: Phoenix PubSub and LiveView
- **APIs**: Forvo, NameShouts, AWS Polly, MapTiler, Nager.Date
- **Testing**: ExUnit + Wallaby for browser automation
- **Development**: Hot reload, Tidewave AI assistance

## Prerequisites

- **Elixir 1.18+** and **Erlang/OTP 26+**
- **Phoenix Framework**
- **PostgreSQL** (v13+)
- **Node.js** (v18+) for asset compilation
- **[direnv](https://direnv.net/)** for environment variable management (recommended)

## Local Development Setup

### 1. Environment Configuration

Copy the example environment file and configure your settings:

```bash
cp .envrc.example .envrc
```

Edit `.envrc` with your configuration:

```bash
# Required - Generate a secret key base
export SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Required - Get free API key from https://www.maptiler.com/
export MAPTILER_API_KEY="your_maptiler_api_key_here"

# Optional - API keys for pronunciation services
export FORVO_API_KEY="your_forvo_api_key_here"
export NS_API_KEY="your_nameshouts_api_key_here"

# Optional - AWS credentials for Polly TTS
export AWS_ACCESS_KEY_ID="your_aws_access_key_here"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_key_here"
export AWS_REGION="us-west-1"
```

If using direnv:
```bash
brew install direnv
direnv allow
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies for assets
npm install --prefix assets
```

### 3. Database Setup

```bash
# Create and migrate database
mix ecto.setup

# This runs:
# - mix ecto.create
# - mix ecto.migrate  
# - mix run priv/repo/seeds.exs
```

### 4. Start Development Server

```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to see the app.

## API Keys & External Services

### Required Services

1. **MapTiler** (Free tier available)
   - Sign up at: https://www.maptiler.com/
   - Used for: Interactive maps and geographical data
   - Free tier: 100,000 map loads/month

### Optional Services (Enhanced Features)

2. **Forvo** (Freemium)
   - Sign up at: https://api.forvo.com/
   - Used for: Real person pronunciation recordings
   - Free tier: 500 requests/day

3. **NameShouts** (Paid)
   - Contact: https://nameshouts.com/
   - Used for: Professional pronunciation recordings
   - Provides name part breakdown for complex names

4. **AWS Polly** (Pay-per-use)
   - AWS account required
   - Used for: AI-generated pronunciation fallback
   - Very low cost: ~$0.0004 per request

## Development Workflow

### Running Tests

```bash
# Run all unit tests
mix test

# Run tests with coverage
mix test --cover

# Run browser tests (requires Chrome)
mix test.browser

# Run browser tests with visible browser for debugging
mix test.browser --show --max-failures=1
```

See [BROWSER_TESTING.md](BROWSER_TESTING.md) for detailed browser testing documentation.

### Code Quality

```bash
# Format code
mix format

# Run static analysis
mix credo

# Type checking (if using Dialyzer)
mix dialyzer
```

### Database Operations

```bash
# Reset database
mix ecto.reset

# Create new migration
mix ecto.gen.migration add_some_feature

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback
```

## Architecture Overview

### Core Modules

- **`Zonely.Audio`** - Main pronunciation orchestration
- **`Zonely.PronunceName`** - Core pronunciation logic and provider management
- **`Zonely.PronunceName.Providers.*`** - External API integrations (Forvo, NameShouts, Polly)
- **`Zonely.PronunceName.Cache`** - Audio caching and S3 storage
- **`Zonely.Accounts`** - User management and profiles
- **`Zonely.Holidays`** - Holiday data and country management
- **`Zonely.TimeUtils`** - Timezone calculations and working hours
- **`ZonelyWeb.*Live`** - Phoenix LiveView modules

### LiveView Pages

- **`MapLive`** - Interactive team map with timezone overlaps
- **`DirectoryLive`** - Team directory with pronunciation features  
- **`HolidaysLive`** - Holiday calendar and team impact
- **`WorkHoursLive`** - Working hours management
- **`NameSiteLive`** - Standalone pronunciation tool

### Data Flow: Pronunciation System

1. User clicks pronunciation button
2. `Audio.play_*_pronunciation/1` orchestrates the process
3. `PronunceName.get_pronunciation/2` tries providers in priority order:
   - Check local cache first
   - Try Forvo API (real recordings)  
   - Try NameShouts API (professional recordings)
   - Fallback to AWS Polly (AI-generated)
   - Final fallback to browser TTS
4. Audio is cached in S3/local storage for future use
5. Frontend receives playback event and plays audio

### Configuration

Key configuration in `config/`:

```elixir
# Timezone overlap calculation
config :zonely, :overlap,
  edge_minutes: 60,
  working_min_minutes: 60,  
  working_min_coverage: 0.5

# Audio cache backend
config :zonely, :audio_cache,
  backend: "s3",  # or "local"
  s3_bucket: "zonely-cache"
```

## Deployment

### Environment Variables (Production)

```bash
# Required
SECRET_KEY_BASE=your_64_char_secret
DATABASE_URL=ecto://user:pass@host/db
PHX_HOST=your-domain.com
MAPTILER_API_KEY=your_key

# Optional (for full features)
FORVO_API_KEY=your_key
NS_API_KEY=your_key  
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_key
AWS_REGION=us-west-1

# Storage
AUDIO_CACHE_BACKEND=s3
AUDIO_CACHE_S3_BUCKET=your-bucket
```

### Docker Compose (Development)

```bash
# Start all services
docker-compose up -d

# Services included:
# - PostgreSQL (port 5432)
# - Redis (port 6379) 
# - MinIO S3 (ports 9000, 9001)
# - MailHog (ports 1025, 8025)
# - MockServer (port 1080)
```

## Contributing

### Code Style

- Follow Elixir conventions and `mix format`
- Write tests for new features
- Update documentation for API changes
- Use descriptive commit messages

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- **LiveView**: Use server-side state management
- **APIs**: Implement graceful degradation when services are unavailable
- **Caching**: Cache external API responses to reduce costs
- **Testing**: Write browser tests for user journeys
- **Performance**: Use database indexes and optimize N+1 queries

## Troubleshooting

### Common Issues

1. **Database Connection**: Ensure PostgreSQL is running and credentials are correct
2. **Asset Compilation**: Run `npm install --prefix assets` if CSS/JS isn't loading
3. **API Keys**: Check that required API keys are set in environment
4. **Browser Tests**: Ensure Chrome and ChromeDriver are installed

### Logging

```elixir
# Enable debug logging
config :logger, level: :debug

# Module-specific logging
config :logger, :console,
  level: :info,
  format: "$time [$level] $metadata$message\n"
```

### Performance Monitoring

- Use Phoenix LiveDashboard at `/dashboard` in development
- Monitor external API response times
- Watch database query performance
- Track pronunciation cache hit rates

## Additional Documentation

- [BROWSER_TESTING.md](BROWSER_TESTING.md) - Browser testing with Wallaby
- [PRONUNCIATION_SETUP.md](PRONUNCIATION_SETUP.md) - Pronunciation system details
- [DESIGN.md](DESIGN.md) - UI/UX design guidelines
- [AGENTS.md](AGENTS.md) - AI development assistant guide