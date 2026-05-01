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

## Implemented Zonely Import Flow

Zonely currently imports SayMyName shares through share links only:

- Card shares are resolved from `https://saymyname.qingbo.us/card/:token`,
  `https://saymyname.qingbo.us/share/:token`, or the same paths on
  `https://saymyname.localhost`.
- List shares are resolved from `https://saymyname.qingbo.us/list/:token` or the
  same path on `https://saymyname.localhost`.
- The resolver unwraps `payload` or `data.payload`, then accepts only
  `version: "shared_profile_v1"`.
- Unsupported versions, non-contract shapes, empty lists, invalid links, failed
  upstream responses, or shares without a valid person identity fail without
  creating draft, people, team, or membership records.

Imported card shares create a reloadable import draft with one draft member.
Imported list shares create a reloadable team draft with one draft member per
valid membership. Invalid list rows are retained as review metadata instead of
creating placeholder people. Drafts are keyed by the source share token so a
same-session replay resumes existing import state, while a different browser
session cannot mutate the draft by copying the review URL.

The completion form asks only for missing Zonely-owned fields:

- `location.country`, stored as a two-letter ISO 3166-1 alpha-2 country code
- `location.label`, used as the city or human-readable location label
- `availability.timezone`, which must be an explicit IANA timezone
- `availability.work_start`
- `availability.work_end`

Imported SayMyName-owned fields remain review context and are not re-prompted:
display name, pronouns, name variants, pronunciation metadata, and role
candidate. A member becomes Zonely-ready only when the display name and all
required Zonely-owned completion fields above are present and valid.

## Implemented Packet, Pass-On, Review, And Publish Flow

Zonely packet invites are local/session-owned team drafts with opaque tokens:

- The owner creates a packet at `/packets/new`.
- Zonely stores hashed owner and invite tokens and shows a shareable
  `/packets/invite/:invite_token` URL.
- The browser session that created the packet keeps the owner authority needed
  to open `/packets/review/:invite_token`.
- Recipient browser sessions get their own submission token after appending a
  profile through the invite link.

Invite links are append-self, not membership-granting links. A recipient can add
or update only their own pending submission. A different recipient session using
the same invite link creates a separate pending submission, which supports
pass-on accumulation from one teammate to the next without overwriting earlier
participants. Recipient, invite, and owner tokens are not interchangeable.

Owner review exposes separate pending, accepted, rejected, excluded, and
published sections. Server-side transitions allow pending entries to remain
pending, become accepted, or become rejected; accepted entries may be excluded
before publish. Rejected or excluded entries cannot be revived by forged
requests. Publishing is owner-only and idempotent: it creates or reuses one
published team and publishes only accepted, complete, non-excluded members.
Pending, rejected, excluded, invalid, or incomplete accepted entries are not
published; incomplete accepted entries block publish until completed or
excluded.

After publish, replaying the same invite or owner review link resolves to the
existing published state instead of opening new mutation paths or creating
duplicate teams, people, memberships, or map markers.

## Privacy And Scope Boundaries

Zonely preserves the split between public card fields and team-only fields:

- Public card context: display name, pronouns when supplied by the card,
  independent name variants, and per-variant pronunciation metadata.
- Team-only context: role, country/location label, timezone, work hours, and
  coordinates.

Recipient invite pages expose the packet context and the recipient's own
submission controls. They do not expose owner review controls or other
participants' team-only fields. Owner review pages show the privacy-impacting
profile, team, location, and availability fields before publish. Published map
and team surfaces use the existing Zonely roster flow and show only accepted
published members.

Coordinates are optional and must be source-provided as a valid
latitude/longitude pair. Zonely does not geocode, infer coordinates from
country, city, timezone, locale, name, role, or pronunciation metadata, or fill
coordinate placeholders. Published map payloads omit coordinate fields for
members without explicit source-provided coordinates.

Out of scope for this contract implementation: OAuth, company directory sync,
address-book import, Slack/Google/Microsoft/LinkedIn integrations, inferred
geocoding, a new authentication system, or a second payload format.

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
