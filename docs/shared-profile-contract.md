# Shared Profile Contract Principles

Zonely and SayMyName should use one shared profile vocabulary. Each app can own
its specialty, but neither app should invent incompatible person, name, team, or
location shapes.

## Standard Reference

Use the current IETF contact standards as the compatibility target:

- JSContact, RFC 9553, is the preferred modern JSON reference for contact-card
  structure and naming.
- vCard 4.0, RFC 6350, remains the long-term `.vcf` export/import target.
- vCard JSContact extensions and conversion guidance, RFC 9554 and RFC 9555,
  should guide fields such as pronouns, phonetic/pronunciation metadata, and
  round-tripping between JSON and vCard.

Internal data does not need to mirror JSContact exactly, but every shared field
should have an obvious JSContact/vCard projection.

## Canonical Terms

Use these terms consistently across Zonely and SayMyName:

- `person`: the human being/contact. Avoid app-specific aliases as the shared
  contract name.
- `profile`: the editable app view of a person. A profile may be incomplete in
  one app and complete in another.
- `name_variant`: one written form of a person's name in one language/script.
  Each variant has its own language tag, display text, and optional
  pronunciation metadata.
- `pronunciation`: audio or phonetic help for a specific name variant.
- `team`: a named group of people.
- `membership`: a person's relationship to a team, including team-specific role
  or visibility when needed.
- `location`: country, place label, coordinates, and related geographic context.
- `availability`: timezone and working-window fields used for reachability.

## Shared Shape

Use a profile shape that can be projected down into either app:

```json
{
  "version": "shared_profile_v1",
  "person": {
    "id": "optional-stable-id",
    "display_name": "San Zhang",
    "pronouns": "he/him",
    "role": "Engineering",
    "name_variants": [
      {
        "lang": "en-US",
        "text": "San Zhang",
        "script": "Latn",
        "pronunciation": {
          "audio_url": null,
          "source_kind": null
        }
      },
      {
        "lang": "zh-CN",
        "text": "Zhang San",
        "script": "Hans",
        "pronunciation": {
          "audio_url": null,
          "source_kind": null
        }
      }
    ]
  },
  "location": {
    "country": "US",
    "label": "San Francisco",
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "availability": {
    "timezone": "America/Los_Angeles",
    "work_start": "09:00",
    "work_end": "17:00"
  },
  "memberships": [
    {
      "team_id": "team-id",
      "team_name": "Zonely Team",
      "role": "Engineering"
    }
  ]
}
```

Fields may be absent when an app does not own or know them. Do not store
placeholder values to make a profile appear complete.

## App Ownership

SayMyName owns:

- name variants as distinct playable rows
- pronunciation lookup, playback metadata, source kind, and audio caching
- name-card and name-list share rendering

Zonely owns:

- team membership and map-first team context
- location, timezone, work hours, daylight, and reachability
- onboarding flows that collect missing team geography and availability fields

Neither app owns the entire shared profile. Each app imports what it can use,
preserves unknown shared fields when practical, and exports the best projection
of what it knows.

## Import And Export Rules

- Every import/export boundary must accept the shared shape and produce a
  deterministic projection into the local app.
- SayMyName import may ignore location and availability, but must preserve the
  name variants and per-variant pronunciation semantics.
- Zonely import may accept a SayMyName card/list as a partial profile, then mark
  location and availability as missing rather than inventing defaults.
- Export from either app should include the shared `version` and use the same
  `person`, `name_variants`, `team`, `membership`, `location`, and
  `availability` terms.
- A list of people should be represented as a `team` plus `memberships`, not as
  an unrelated ad hoc list format.

## vCard Projection

Long-term vCard export should map the shared terms this way:

| Shared field | vCard / JSContact direction |
| --- | --- |
| `person.id` | `UID` |
| `person.display_name` | `FN` |
| `name_variants[].text` | `FN` / `N` with `LANGUAGE`, `ALTID`, and optional `SCRIPT` |
| `person.pronouns` | `PRONOUNS` |
| `person.role` | `ROLE` or `TITLE`, depending on app meaning |
| `memberships[].team_name` | `ORG` for org context, or group card `FN` |
| `team` | `KIND:group` plus `MEMBER` links |
| `availability.timezone` | `TZ` using IANA timezone names, not fixed UTC offsets |
| `location.latitude` / `location.longitude` | `GEO:geo:lat,lng` |
| `location.country` / `location.label` | `ADR` or JSContact address/location fields |
| `name_variants[].pronunciation.audio_url` | `SOUND` or JSContact media/link projection |

Zonely-specific working hours are app-owned availability metadata. They should
round-trip inside the shared JSON contract, but vCard export may use an
extension field such as `X-ZONELY-WORK-HOURS` until a better standard mapping is
chosen.

## Agent Rules

- Before changing onboarding, profile, team, import, export, or SayMyName
  integration code, read this document first.
- Do not add a new person/list/team payload without mapping it back to this
  shared shape.
- Prefer additive contract evolution: add optional fields and bump `version`
  only when old readers cannot safely interpret the payload.
- Keep language tags BCP 47-compatible, such as `en-US` and `zh-CN`.
- Keep each name variant independently playable. Do not collapse all variants
  behind one language switcher or one pronunciation button.
