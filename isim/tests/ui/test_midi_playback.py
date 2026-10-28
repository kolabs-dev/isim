"""MIDI playback (HelloAudio, -midi; issue #389): AVAudioUnitSampler rendered offline (its sine voice, a SoundFont
preset the sample writes, audio files, gain, tuning, pitch bend, controllers), AVAudioSequencer and AVMusicTrack (events,
editing, a Standard MIDI File round trip, playback to a sampler in a running engine and to a CoreMIDI destination with a
loop), the Music Player C API, AVMIDIPlayer, Audio File Stream Services and CAClock. The engine plays through SDL's
silent "dummy" device."""
import re


def test_midi_playback(launch):
    app = launch("HelloAudio", args=["-midi"], env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy"})
    app.wait_log(r"HelloMIDIPlayback: done", timeout=60)
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def line(p):
        m = re.search(f"^.*HelloMIDIPlayback: {p}.*$", log, re.M)
        return m.group(0) if m else f"no {p!r} line"

    def has(p):
        return re.search(f"HelloMIDIPlayback: {p}", log)

    # the sampler, offline (48 kHz)
    assert has(r"sampler sine freq 4[34]\d crest 1\.[3-7]\d"), \
        f"before an instrument is loaded, a sine voice (crest ~1.4-1.7 with its envelope): {line('sampler sine')}"
    assert has(r"sampler sf2 error none freq 8[78]\d crest (0\.9\d|1\.0\d)"), \
        f"the SoundFont's looped square wave (crest 1), an octave above its root key: {line('sampler sf2')}"
    assert has(r"sampler stop rms 0\.00"), f"a stopped note goes silent: {line('sampler stop')}"
    assert has(r"sampler gain -12 ratio 0\.2[4-6]"), f"overallGain -12 dB is a quarter of the amplitude: {line('sampler gain')}"
    assert has(r"sampler tuning 1200 freq 8[78]\d value 1200"), f"globalTuning +1200 cents is an octave up: {line('sampler tuning')}"
    assert has(r"sampler bend freq 49\d volume0 rms 0\.00"), \
        f"full pitch bend is two semitones up; controller 7 at 0 silences: {line('sampler bend')}"
    assert has(r"sampler files error none freq 33\d"), f"an audio file keyed A3 by its name, played a fifth up: {line('sampler files')}"
    assert has(r"sampler missing error -43"), f"a missing instrument file is fnfErr: {line('sampler missing')}"
    assert has(r"soundbank status 0 0 name isim square presets Square:121:0:0"), \
        f"CopyNameFromSoundBank and CopyInstrumentInfoFromSoundBank (melodic bank MSB 0x79): {line('soundbank')}"
    # the sequencer's model
    assert has(r"sequencer tracks 1 length 2\.50 seconds 2\.00 beats 4\.00"), f"length and the tempo map (60 BPM): {line('sequencer tracks')}"
    assert has(r"sequencer events ControlChange,Meta,Note,Note,Note,PitchBend,ProgramChange notes 0\.00,1\.00,3\.00 bends 0"), \
        f"the event classes; the block moves a note and removes the bend: {line('sequencer events')}"
    assert has(r"sequencer smf bytes true error none tracks 1 keys 60,64,67 seconds 2\.00"), \
        f"a Standard MIDI File written and read back, with its tempo: {line('sequencer smf')}"
    assert has(r"sequencer cut 0\.00,2\.00 copied 2 cleared 0 removed true tracks 1"), f"cut, copy, clear, removeTrack: {line('sequencer cut')}"
    assert has(r"track looping true loops -1 muted true offset 1\.00 resolution 480"), f"track properties: {line('track looping')}"
    # Audio File Stream Services and CAClock
    assert has(r"stream ready true rate 22050 channels 1 bits 16 bytes 44100 packets 22050 offset 44 properties ffmt,dfmt,doff"), \
        f"a WAV file parsed in 1000-byte pieces: {line('stream')}"
    assert has(r"clock tempo 90 smpte 1:1:1 bar 3 beat 2 subbeat 240 beats 9\.50"), f"CAClock conversions: {line('clock')}"
    # real-time playback
    assert has(r"sequencer start error none playing true destination true"), line("sequencer start")
    assert has(r"sequencer played notes 3 peak true position true playing false"), \
        f"the looping track's three notes at a CoreMIDI destination; the sampler heard by the tap: {line('sequencer played')}"
    assert has(r"musicplayer start 0 tracks 1 seconds 0\.50"), line("musicplayer start")
    assert has(r"musicplayer notes 4 playing true beat true"), f"a MusicPlayer to a CoreMIDI destination: {line('musicplayer notes')}"
    assert has(r"midiplayer duration 0\.38 rate 1\.00"), f"AVMIDIPlayer's duration from the file's tempo: {line('midiplayer duration')}"
    assert has(r"midiplayer playing true"), line("midiplayer playing")
    assert has(r"midiplayer completed after true playing false"), f"the completion handler at the end: {line('midiplayer completed')}"
    assert has(r"midiplayer invalid error true"), f"data that is not a MIDI file throws: {line('midiplayer invalid')}"
