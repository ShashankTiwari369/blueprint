# Fyno teardown: consent storage, versioning, and preference center

_Date: 2026-10-19. Method: REA (Reverse Engineer Anything, `morluto/rea`) plus Fyno's public docs and OpenAPI spec._

## TL;DR

- **Fyno stores preferences, not consent.** Each user has a per-topic, per-channel state (`opted-in` / `opted-out`) and a per-channel `updated_at` string. It does not store a consent source, IP address, user agent, policy or notice version, consent text, or proof.
- **There is no history.** Each save overwrites the current state. Fyno has no documented audit log of preference changes. Change logs exist only for templates, secrets and groups.
- **Versioning covers config, not consent.** Templates, routes, events and workflows have Test versions (v1, v2…) that are promoted to Live through optional maker-checker approval. Preference sections and topics are **not** versioned and **not** promotable between environments.
- **The preference center is an embedded widget, not a hosted page.** It lives inside the in-app notification bell SDK (`@fyno/inapp-react`), talks over a websocket, and authenticates with a static HMAC. The only hosted pages are unsubscribe/resubscribe screens reached from email/SMS links.
- **DPDP consent is outsourced.** Marketing positions Fyno as an *enforcement layer* that queries your CMP (consent manager platform) before each send. None of that appears in the API spec or SDKs.

**Opportunity:** an append-only, versioned consent ledger with proof, plus a hosted, brandable preference center, is the gap.

---

## 1. Method and evidence

The sandbox network policy blocked all `*.fyno.io` hosts, so the live web app and dashboard could not be captured. The analysis uses the artifacts Fyno ships publicly:

| Artifact | How it was analysed | What came out |
|---|---|---|
| `@fyno/inapp-react@2.0.0-alpha-04` (npm) | REA `analyze-javascript-application`, evidence `ev_6bc68c8f…` | Source maps include `sourcesContent`. 74 original first-party files were recovered, including `GlobalPreference.jsx`, `ConfigComponents.jsx`, `PreferenceButton.jsx` and `NotificationsHomeContext.js` |
| `@fyno/websdk@2.0.9` (npm) | REA + decoding the webpack `eval` modules | `config.js`, `profile.js`, `webpush.js`, `utils.js` and `customPopupConfig.js` recovered |
| `@fyno/node@1.2.3` (npm) | Shipped `src/` read directly | Server SDK: profiles and channel tokens only |
| `@fyno/react-native@5.0.0`, `@fyno/react-hooks@2.0.2` | REA | Thin wrappers over the same socket protocol |
| `fynoio/flutter_inapp_sdk` (GitHub) | grep | Inbox only, no preference UI |
| `fynoio/documentation` (GitHub; Fern docs plus `openapi.yml`) | Read directly | API schemas, product docs, release notes |

Labels used below: **[CODE]** = seen in shipped code. **[DOC]** = Fyno documentation or OpenAPI spec. **[INF]** = inference. **[CLAIM]** = marketing claim, not verified.

---

## 2. How consent and preferences are stored

### 2.1 Data model

```
Workspace (WSID)
 └─ Environment: test | live           ← users and opt-outs are separate per environment
     ├─ Profile (distinct_id)
     │    status: 1|0                  ← master kill switch
     │    channel: { email, sms, whatsapp, rcs, voice, slack, discord, teams,
     │               push[], inapp[], webpush[] {token, integration_id, status} }
     ├─ Section (e.g. "Engagement")     ← UI-only grouping
     │    └─ Subscription topic (subscription_id "SXXXXXXXXX")
     │         channel_config: { <ch>: on | off | required }   ← the workspace default
     │         preference:     { <ch>: opted-in | opted-out }  ← the user's choice
     │         updated_at:     { <ch>: string }                ← the ONLY consent metadata
     │         notification_events: [{event_id, event_name}]   ← an event maps to ≤1 topic
     ├─ Global opt-out: meta.all.preference { <ch>: opted-out }, updated_at
     └─ Suppression list (separate layer): distinct_id|destination, channel,
          reason, event_type ∈ {otp, transactional, marketing}, created_at, expiry_ts
```

- **[DOC]** `on` means opt-out model: the user is sent messages until they opt out. `off` means opt-in model. `required` means the user cannot change it (e.g. OTP), and Unsubscribe is disabled for it.
- **[DOC]** `GET /v1/{WSID}/{version}/subscriptions/preference?distinct_id=…` returns `result` keyed by section name, plus `meta.all` for global opt-outs.
- **[DOC]** `PUT …/subscriptions/preference?distinct_id=…` takes body `{"user_preference": {"<subscription_id>|all": {"<channel>": "opted-in|opted-out"}}}`.
- **[DOC]** `POST …/subscriptions/list/{subscription_id|all}/user` takes `{distinct_id, channel, status}`.

### 2.2 What a consent record lacks

The OpenAPI spec was grepped for consent, IP, user agent, audit and history fields. Only `updated_at` and `is_global_opted_out` exist.

| Consent-record element (DPDP/GDPR-grade) | Fyno |
|---|---|
| Current state per purpose/channel | ✅ topic × channel |
| Timestamp of last change | ⚠️ `updated_at` per channel (a string, last write only) |
| Source/surface (in-app, email link, API, WhatsApp "STOP", admin) | ❌ |
| Actor (user vs admin vs API key) | ❌ |
| IP address / user agent / device | ❌ |
| Notice, policy or consent-text version shown | ❌ |
| Append-only history | ❌ (overwritten in place) |
| Consent artifact ID / receipt | ❌ natively. [CLAIM] links to an external CMP's artifact ID |
| Expiry / re-consent | ❌ for preferences. Suppression entries have `expiry_ts`; the new Consent Form has an expiring *link* |

### 2.3 The client never sends context

**[CODE]** The in-app SDK saves preferences with exactly this:

```js
socketInstance.emit('set:preference', updatedPreference)
// updatedPreference = { "<subscription_id>": { "email": "opted-out" }, "all": { "sms": "opted-out" } }
```

The payload carries no timestamp, notice version or UI context. The server can only add what it sees on the socket: user ID, workspace, integration and arrival time. The success response is just a `preference:update` event, which triggers a toast ("Channel preference updated") and a re-fetch.

### 2.4 Web push consent is device-local only

**[CODE]** `@fyno/websdk` keeps the push permission state in the browser's IndexedDB (database `fyno-websdk`, object store `config`). It uses these keys:

| Key | Values / contents |
|---|---|
| `push_status` | `allowed` \| `denied` \| `pending` \| `remind_later` |
| `fyno_push_permission` | Mirror of `Notification.permission` |
| `fyno_push_subscription` | Serialised PushSubscription |
| `fyno:distinct_id` | The user's ID |
| `verify_token` | JWT used on API calls |

A `remind_later` cookie lasts 12 hours. A "Deny" on Fyno's soft-ask pop-up is stored **only locally** (`console.log('User denied custom popup. Do nothing.')`). Only an "Allow" reaches the server, as a webpush token on the profile.

### 2.5 Other channels

- **[DOC] WhatsApp:** opt-in/out comes from a template button payload. A workflow can map an inbound "Stop promotions" message to a Subscription action that sets "Opted-Out". It writes to the same preference store, so it has the same lack of provenance.
- **[DOC] SMS (India DLT):** consent templates are registered with the telecom operator's consent registrar, outside Fyno.
- **[DOC] Consent Form** (new, release 2026-10-11): an expiring link with a consent checkbox, where submit is disabled until the box is ticked. Submitting can trigger an event. Where the submission is stored, and with what fields, is undocumented.
- **[CLAIM] DPDP:** "Fyno queries your CMP before every send… every log links to a consent artifact ID from your CMP." This is positioned as enforcement on top of a third-party CMP, not as Fyno being the system of record.

---

## 3. Versioning

| Object | Versioned? | Details |
|---|---|---|
| Templates | ✅ | Test v1, v2… promoted to Live via Go Live. Change log records who, which version and when. Going live switches every event, workflow and campaign using it immediately |
| Routes, notification events, workflows | ✅ | Same Test → Live model |
| Approvals | ✅ (optional) | Maker-checker Requests with Pending, Approved, Live and Rejected tabs, and required reasons |
| Rollback | ❓ | Not documented. "Reset" only discards unsaved edits |
| **Preference sections/topics** | ❌ | Not versioned and not promotable. Edited directly in the UI, with no create/edit API |
| **User consent / preferences** | ❌ | Stored per environment (`version` = test\|live in the URL), but that is environment separation, not history |

**[INF]** So "version" in Fyno's API (`/{WSID}/{version}/…`) means the **environment** (test/live), not a revision. If an admin flips a topic's default from `off` to `on`, every user who never made an explicit choice changes effective state silently. Nothing records which default a user was under when a message was sent.

---

## 4. Preference management center

### 4.1 Where it lives

- **[CODE]** It is embedded in the in-app inbox (`@fyno/inapp-react`). It is not a standalone page and has no dedicated web component. `themeConfig.preference_mode` takes:
  - `'none'` (the default: hidden)
  - `'embed'` (a settings panel inside the bell drawer)
  - `'modal'` (a pop-up)
- **[DOC]** The hosted surfaces are limited to:
  - The `{{$fyno.$unsubscribe.url}}` link: a confirm step, then an unsubscribed page with a **Resubscribe** button. It is scoped to the topic and channel of that message.
  - A one-click List-Unsubscribe header, for SES and Postmark only.
- **[DOC]** Flutter has no preference UI. React Native and the hooks packages expose the socket, so you build the UI yourself. You can also build a custom UI on the GET/PUT REST APIs.

### 4.2 Protocol (in-app)

**[CODE]** It runs on Socket.IO to `https://inapp.fyno.io`:

```
connect   auth: { user_id, WS_ID, Integration_ID, 'x-fyno-signature' }
          headers: x-fyno-signature, cookie x-fyno-cookie=<signature>
emit  get:preference            → on preferences:state  { result: {Section: [topic…]}, … }
emit  set:preference {diff}     → on preference:update  → toast + re-fetch
```

The signature is `HMAC_SHA256(key = WSID + INTEGRATION_TOKEN, msg = USER_ID)`, hex encoded.

### 4.3 UI behaviour (recovered source)

- **Layout:** Section headings, each followed by topic rows. Each topic row holds a chip per channel.
- **Chip states:** `opted-in` (check icon), `opted-out` (muted), `required` (lock icon, tooltip "*X is a required channel*", not clickable).
- **Global channel toggles:** an optional `globalChannels: ['sms','whatsapp',…]` prop on the client adds "Notify me on {Channel}" switches above the topics. The copy reads "*By opting out, you won't receive any communications on this channel.*" Turning a global off greys out that channel on every topic, with the tooltip "*X is globally opted-out*". Turning it back on resets each topic to its **default** (`on` → opted-in), not to the user's earlier choice.
- **Save model:** edits are batched. A Save button appears only if state differs from the snapshot. Leaving with unsaved changes prompts "*Do you want to save the changes made?*" with Yes/No.
- **Channel labels** are hard-coded: In-App, WhatsApp, SMS, Email, Push, WebPush, Slack, Discord, Teams, Voice. RCS is missing even though the profile model supports it.
- **Branding:** a theme config sets logo, header, position and offset. A "Powered by Fyno" badge can be turned off server-side (`config.branding`).

### 4.4 Gaps and risks found in the code

1. **The HMAC signature never expires.** It has no timestamp or nonce. Anyone who obtains it can read and change that user's preferences indefinitely, until the integration token is rotated.
2. **The README shows computing the HMAC in the browser** (CryptoJS example). That would expose `WSID + INTEGRATION_TOKEN` to clients.
3. **Web SDK token bootstrap:** `GET https://api.fyno.io/v2/{wsid}/{distinct_id}/token` is fetched with no credentials to obtain the `verify_token` JWT. [INF] Server-side checks may exist (e.g. origin), but the client sends none.
4. **Global re-enable discards per-topic choices.** It resets topics to the workspace default.
5. **Node SDK bugs:** `setEmail()` and `setSms()` both write to the `slack` channel.
6. **The web-push "Deny" is never synced** to the server, so it cannot be audited.

---

## 5. Enforcement at send time

- **[DOC]** When an event linked to a topic fires, Fyno drops channels the user has opted out of (topic, global, or default `off`). Logs show `SUBSCRIPTION "<topic> - User opted-out from channel(<state>)"`, with status **Dropped** or **UNSUBSCRIBED**.
- **[DOC]** Override is by configuration only: `required` channels, suppression scoped by otp/transactional/marketing, and DND rules per channel and category. The `/event` payload has no per-request `override_preferences` flag.
- **[DOC]** Preferences need a `distinct_id`. Sends made by raw `to` address bypass the topic preference layer, leaving only suppression.

---

## 6. Implications for our product (input to `/pm:validate`)

| Fyno gap | What a better design would do |
|---|---|
| State-only, last-write-wins | Append-only **consent events** (`subject, purpose/topic, channel, action, actor, source, notice_version, ip/ua hash, ts`) with current state derived from them |
| No notice/policy version | Version the **notice** (copy, purposes, defaults) and stamp every consent event with it. Trigger re-consent when the material version changes |
| Topic defaults editable in place | Version the **preference schema** (sections, topics, defaults). Record which schema version applied at send time |
| Consent outsourced to a CMP | Native DPDP consent artifact, with optional CMP sync |
| Preference center only inside the in-app bell | A hosted, brandable preference page with signed, **expiring** links, plus embeddable components |
| Static HMAC auth | Short-lived signed tokens (JWT with `exp`, scoped to the preference API) |
| Web push deny kept local | Sync every permission outcome as a consent event |
| Global re-enable loses choices | Keep topic choices and make global a separate overlay |

## Open questions

- What does `inapp.fyno.io` persist on `set:preference`? Socket arrival metadata may be logged internally. That needs live capture, which this sandbox's network policy blocked.
- What does the new Consent Form store (fields, retention)?
- Is the CMP-integration claim in the [CLAIM] items real product or roadmap?
