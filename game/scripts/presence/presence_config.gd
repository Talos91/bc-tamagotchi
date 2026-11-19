extends RefCounted
## Supabase project for presence (docs/design/08b-presence-api.md §7). Both values are public by design: every table
## has row-level security and clients only call the bc_* functions. Service-role and VAPID private keys live only
## inside Supabase. Empty URL = presence off (Presence.ON false).

const URL := ""
const ANON_KEY := ""
