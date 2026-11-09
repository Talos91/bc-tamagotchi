# 🛠️ iphone-load-2 — role note 2026-11-09 (owner item 28)
Worker: Sonnet; load id 2026-11-09-release-black-cabin-f5152c (no tech role exists; `release` was the nearest, profile mismatch worth fixing). Commit e43a9ec.
State: live files all fine; cause = unprotected mid-stream network error in the engine's wasm read; fix = Range resume + diagnostic line in the banner (`SHELL_GUARD` in tools/build_web.py). Needs redeploy by Daniele and an iPhone retest.
Next step if it still fails: the banner's "Last download:" line names file/status/MB; if the wasm is reached fully and it fails later, look at memory (engine tees the wasm response; consider raw-reading instead via a custom Godot html shell) or lighter textures.
Gotchas: see the report. Test cut server idea: close the connection at 24 MB on the first wasm GET.
