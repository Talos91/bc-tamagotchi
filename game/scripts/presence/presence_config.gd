extends RefCounted
## Supabase project for presence (docs/design/08b-presence-api.md §7). Both values are public by design: every table
## has row-level security and clients only call the bc_* functions. Service-role and VAPID private keys live only
## inside Supabase. Empty URL = presence off (Presence.ON false).

const URL := "https://czrbsjalcjekcslylwbt.supabase.co"
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6cmJzamFsY2pla2NzbHlsd2J0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUwOTc2MzYsImV4cCI6MjExMDY3MzYzNn0.Ylr35L_4R63d9uJFDUvn7Qy9HPiy_rP8QKZw4_I15yY"
