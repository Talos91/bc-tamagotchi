# Owner feedback 2026-11-09 (Daniele, in chat, live build c495a35 on the phone)

Continues the numbering of `owner-feedback-2026-11-04.md` (items 17–25).

26. (2026-11-09 ~20:40 +7) Creator on the phone: "works but once i press done or if i try to exit it.... it just don t let me". → 🎨 character-creator fix: Done and the exit must leave the creator on the web build (touch); reproduce at 375×812 in a browser with touch emulation, not only desktop click; regression check in `test_avatar` or `smoke_start`.
27. (same) "theres no female hair all characters looks male". → 🎨 character-creator fix: the eight hair styles (Q3) must include clearly feminine options (long, bob, ponytail, bun … whatever the kit's 17 styles offer; generate one or two if the kit has none), and the three starter looks (Q5) must not all read male; show the result on a card with portrait captures. Q10 stands (no gender field, every part on every body).
