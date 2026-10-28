"""MIDI playback from C and Objective-C (issue #389): MIDIPlaybackTest.app checks Music Sequence, Music Player, the
Sampler unit through MusicDevice.h, Audio File Stream Services, CAClock and the AVFAudio classes (AVAudioUnitSampler,
AVAudioSequencer, AVMusicTrack with AVBeatRange, the AVMusicEvent classes, AVMIDIPlayer) through Apple's names."""
from isimtest import need_apps, selftest


def test_midi_playback_objc(device_data):
    need_apps("MIDIPlaybackTest")
    selftest("MIDIPlaybackTest", data=device_data)
