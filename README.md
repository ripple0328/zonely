# SayMyName

**Enter any name, hear it pronounced correctly — in multiple languages, from real native speakers.**

## About

SayMyName is a name pronunciation tool that helps you learn how to say any name correctly. It aggregates pronunciations from native speaker recordings and AI-generated audio, supporting names across dozens of languages. A companion iOS app provides on-the-go access with real-time analytics.

**Live at [saymyname.qingbo.us](https://saymyname.qingbo.us)**

## Features

- **Multi-source pronunciation** — Real recordings from [Forvo](https://forvo.com/) and [NameShouts](https://www.nameshouts.com/), with AWS Polly as an AI fallback
- **Multi-language support** — Hear names pronounced in their native language and others
- **iOS companion app** — Native SwiftUI app with pronunciation playback, deep link sharing, and live analytics
- **Public analytics dashboard** — Play counts, geographic distribution heatmap, top names, top languages, and time-series charts
- **Real-time streaming** — WebSocket channels push live analytics updates to the iOS app

## Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Elixir, Phoenix 1.8, LiveView, PostgreSQL |
| **iOS** | SwiftUI, AVFoundation, WebSocket (iOS 16+) |
| **Infrastructure** | macOS server (Mac Mini), launchctl, Cloudflare tunnel, Docker (PostgreSQL) |

## Getting Started

For local development setup, see:

- [DEVELOPERS.md](DEVELOPERS.md) — Dev environment, running the server, tests
- [PRONUNCIATION_SETUP.md](PRONUNCIATION_SETUP.md) — API keys for Forvo, NameShouts, and AWS Polly

## iOS App

A native SwiftUI companion app lives in the `ios/` directory. See [ios/README.md](ios/README.md) for build instructions and details.

## Deployment

Deploy to production with:

```sh
./deploy.sh
```

The app is live at [saymyname.qingbo.us](https://saymyname.qingbo.us).