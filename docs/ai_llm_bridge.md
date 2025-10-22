# AI LLM Bridge Integration

This document explains how the tgstation AI can be proxied through a large language model (LLM) by way of an OpenAI-compatible API. It covers the moving pieces of the new control pipeline, configuration, runtime behaviour, and extension points for server operators.

## High-Level Overview

1. **AI mob emits events** – speech seen over cameras, spoken messages, radio transmissions, and holopad chatter are normalised into structured payloads.
2. **`/datum/ai_control_link` brokers traffic** – the link fans events out to whichever control driver is active (player, LLM, or fallback) while invoking the new `SSai_llm` subsystem for logging/forwarding.
3. **`SSai_llm` persists and forwards** – each AI has a `datum/ai_llm_session` that stores the rolling event log and a cached law snapshot; when the LLM bridge is enabled, events are posted to the remote service.
4. **Bridge replies with instructions** – the HTTP response (if any) contains a list of actions; `SSai_llm` maps them to standardised instructions and feeds them back into the control link.
5. **LLM driver executes** – `/datum/ai_control_driver/llm` sanitises action payloads, translates chat channel mnemonics to BYOND prefixes, and routes output through the standard `mob.say()` APIs so that existing logging, rate limits, and moderation still apply.

Notably, the AI remains completely playable by a human. The LLM pathway is opt-in and can be toggled per-AI using an admin verb or globally via configuration.

## Key Components

### `/datum/ai_control_link`

- Owns the active control mode (`player`, `llm`, or `fallback`) and a map of instantiated drivers.
- Forwards inbound events to the active driver and optionally to `SSai_llm`.
- Provides helpers (`get_modes()`, `get_driver()`, `switch_to_mode()`) consumed by admin tooling and the subsystem.

### `/datum/ai_control_driver/llm`

- Tracks whether it is *actively listening* (`actively_listening = TRUE`) which only occurs while the bridge is enabled in configuration.
- Handles instructions:
  - `say` – freeform station speech (optionally forced).
  - `radio` – identical to `say`, but converts channel mnemonics such as `command` or `science` into their BYOND prefixes.
  - `do` – placeholder for future verb/tool integrations. Right now it only logs the event for diagnostics.
- Sanitises payloads via `sanitize_text`, trims whitespace, and applies optional flags (`forced`, `ignore_spam`, `filterproof`).

### `SSai_llm`

- Responds to config reloads to refresh runtime switches, bridge URL, API key, and timeout.
- Maintains active sessions keyed by `REF(ai)` and persists a rolling log of the most recent 100 events per AI.
- Posts event JSON to `POST {base_url}/sessions/{session_id}/events`. A successful response (2xx with JSON) is expected to include an `actions` list; anything else is treated as best-effort logging.
- Converts responses into control instructions and queues them through the AI control link so they run inside BYOND’s normal command flow.

### Configuration Keys

All toggles live in `config/game_options.txt` (or your site-specific overrides):

| Option                          | Type    | Default | Description                                              |
|---------------------------------|---------|---------|----------------------------------------------------------|
| `ai_llm_bridge_enabled`         | flag    | `false` | Master enable for the subsystem.                         |
| `ai_llm_bridge_base_url`        | string  | `""`    | Root URL of the OpenAI-compatible bridge (no trailing `/`). |
| `ai_llm_bridge_api_key`         | string  | `""`    | Optional bearer token used for authentication.           |
| `ai_llm_bridge_timeout`         | number  | `5`     | HTTP timeout (seconds) for outbound bridge calls.        |

Changes take effect on config reload or server restart. When the bridge is disabled the LLM driver automatically relinquishes output and the AI behaves as a normal player-controlled mob.

## Event and Action Payloads

### Outbound Event (server → bridge)

```json
{
  "session_id": "REF(/mob/living/silicon/ai)",
  "ai_ref": "REF(/mob/living/silicon/ai)",
  "event": {
    "type": "speech|radio|holopad|system",
    "timestamp": 123456,
    "payload": { /* mode-specific data */ }
  },
  "laws": [
    "You may not injure a human...",
    "You must obey orders..."
  ],
  "metadata": {
    "name": "AI",
    "real_name": "AI",
    "job": "AI",
    "control_mode": "llm"
  }
}
```

The `payload` mirrors the data built in `ai.dm` and `ai_say.dm`. For example, local speech includes the original text, translated text, speaker references, and any spans/modifiers.

### Inbound Actions (bridge → server)

```json
{
  "actions": [
    { "type": "say", "payload": { "message": "Hello crew." } },
    { "type": "radio", "payload": { "channel": "command", "message": "Command, status green." } }
  ]
}
```

`type` is case-insensitive; unknown actions are ignored. `payload` is optional but should at minimum include `message` for `say`/`radio`.

## Admin Controls

- **Verb:** `Configure AI Control Mode` (Admin category) is added to each AI. Selecting `"llm"` only succeeds when `ai_llm_bridge_enabled` is set and the AI’s control link has an LLM driver.
- **Runtime switching:** The system is designed so you can swap between human, LLM, and fallback control without a server restart. Switching away from `llm` immediately stops outbound HTTP requests.
- **Logging:** Failed HTTP requests and unsupported action payloads are logged via `log_world` under the `AI-LLM` tag.

## Operational Notes

- **Rate limiting:** No explicit throttling is implemented yet. Heavy traffic should be managed by the external bridge service or future enhancements.
- **Security:** Authentication uses a bearer token if provided; otherwise no header is sent. The bridge must be hosted in a trusted environment because it acts on behalf of the AI.
- **Payload size:** Session logs keep only the last 100 events per AI. The bridge can implement additional summarisation/compaction if required.
- **Fallback behaviour:** The fallback driver today simply mirrors the player driver, but the slot exists so operators can add deterministic, non-LLM behaviour if desired.

## Extending the Bridge

1. **Custom actions** – add new instruction constants in `code/__DEFINES/ai/ai_control.dm`, teach `SSai_llm` how to map them in `dispatch_instructions()`, and implement the handling proc inside `datum/ai_control_driver/llm`.
2. **Tool access** – when introducing verbs or machinery interactions, respect the existing visibility and distance checks (`can_see()`, `can_perform_action()`).
3. **Session metadata** – extend `datum/ai_llm_session` to snapshot extra state (alerts, cameras, etc.) and include it in the outbound `metadata` block.
4. **Testing** – the subsystem can be pointed at a mock HTTP server to simulate the bridge while keeping the production flag disabled.

## Quick Start

1. Deploy (or configure) an OpenAI-compatible REST service that accepts POSTs to `/sessions/{id}/events` and returns action JSON.
2. Populate the new config keys:
   ```
   ai_llm_bridge_enabled = true
   ai_llm_bridge_base_url = https://llm.example.internal
   ai_llm_bridge_api_key = secret123
   ai_llm_bridge_timeout = 10
   ```
3. Restart or reload configuration.
4. Use the admin verb on an AI (`Configure AI Control Mode`) and choose `llm`.
5. Monitor logs for `AI-LLM` messages to confirm connectivity and explore instrumenting your bridge for visibility.

With these steps complete, the AI will stream events to the bridge, and any returned actions will be executed through the normal speech pipeline, complete with logging, filtering, and law enforcement.
