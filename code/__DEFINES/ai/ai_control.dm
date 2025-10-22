#define AI_CONTROL_MODE_PLAYER "player"
#define AI_CONTROL_MODE_LLM "llm"
#define AI_CONTROL_MODE_FALLBACK "fallback"

/// Event types the AI control interface can emit
#define AI_CONTROL_EVENT_SPEECH "speech"
#define AI_CONTROL_EVENT_RADIO "radio"
#define AI_CONTROL_EVENT_HOLOPAD "holopad"
#define AI_CONTROL_EVENT_SYSTEM "system"

/// Outgoing instruction tokens used by control drivers to request AI actions
#define AI_CONTROL_INSTRUCTION_SAY "say"
#define AI_CONTROL_INSTRUCTION_RADIO "radio"
#define AI_CONTROL_INSTRUCTION_DO "do"
