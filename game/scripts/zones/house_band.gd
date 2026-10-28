extends Node
## The house band's set on loop (GDD §14: one set of 4 songs on loop, applaud between songs). Each song lasts
## SONG_SECONDS, then a BREAK_SECONDS gap in which applause counts. Runs on real time (not the debug game clock), so
## a song always sounds like a song. Stand-in until the performance system (GDD §6) schedules real sets.

signal song_started(song: int)
signal song_ended(song: int)

const SONGS := 4
const SONG_SECONDS := 60.0   ## matches a Front Row Rhythm song
const BREAK_SECONDS := 12.0

var song := 0          ## 0..3, the song playing or the one that just ended
var playing := true
var t := 0.0           ## seconds into the current song or break


func _process(delta: float) -> void:
	advance(delta)


func advance(dt: float) -> void:
	t += dt
	while true:
		if playing and t >= SONG_SECONDS:
			t -= SONG_SECONDS
			playing = false
			song_ended.emit(song)
		elif not playing and t >= BREAK_SECONDS:
			t -= BREAK_SECONDS
			playing = true
			song = (song + 1) % SONGS
			song_started.emit(song)
		else:
			break


func seconds_left() -> float:
	return (SONG_SECONDS if playing else BREAK_SECONDS) - t


## Debug: jump to the end of the current song or break.
func skip() -> void:
	advance(seconds_left() + 0.01)
