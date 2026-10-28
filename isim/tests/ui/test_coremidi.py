"""CoreMIDI (HelloMIDI; issue #390): isim's MIDI server. The simulated "isim MIDI" device receives what the app sends
(logged by CoreMIDI) and, through the `midi` script command, sends notes that a MIDI 2.0 input port hears up-converted;
taking it offline notifies the client. Virtual endpoints, a thru connection (channel map, transposition, a filter),
system-exclusive messages in the background, MIDI 2.0 messages down-converted for a MIDI 1.0 destination, the Swift
builders, a UMP endpoint and the network session are checked in the log."""


def test_coremidi(launch):
    app = launch("HelloMIDI")
    app.wait_log(r"HelloMIDI: ready", timeout=20)
    app.wait_log(r"HelloMIDI: sources=1 destinations=1 devices=1")
    app.wait_log(r"HelloMIDI: device isim MIDI entities=1 manufacturer=isim offline=0 uid=true")
    # the app's packet list (one packet: same time stamp) at the isim MIDI destination
    app.wait_log(r"HelloMIDI: sent to isim MIDI packets=1 status=0")
    app.wait_log(r"CoreMIDI: isim MIDI received 90 3C 64 80 3C 00")
    # through the thru connection: channel 1 to 4, an octave up, the control change filtered out
    app.wait_log(r"HelloMIDI: virtual destination got 93 48 64")
    assert "virtual destination got B" not in app.log
    # MIDI 2.0 to a MIDI 1.0 destination: velocity 0xFFFF to 127, the pitch bend's center to 0x2000
    app.wait_log(r"HelloMIDI: legacy got 2091407F 20E10040")
    app.wait_log(r"HelloMIDI: virtual destination got F0 7E 7F 06 01 F7")
    app.wait_log(r"HelloMIDI: sysex complete=1 left=0")
    app.wait_log(r"HelloMIDI: builders bytes=B0 07 64 time=42 words=1 type=2")
    app.wait_log(r'HelloMIDI: ump endpoints=\["Monitor UMP"\] blocks=1 source=true')
    app.wait_log(r"HelloMIDI: network enabled=true contacts=1 source=Network")
    app.wait_log(r"HelloMIDI: added Monitor Out type=2")

    # the simulated device plays: up-converted to MIDI 2.0 (velocity 127 is 0xFFFF, 64 is 0x8000)
    app.send("midi send 90 40 7f")
    app.wait_log(r"HelloMIDI: from isim MIDI: note on 64 velocity FFFF channel 1 \(MIDI 2\.0\)")
    app.send("midi note 60 64 3")
    app.wait_log(r"HelloMIDI: from isim MIDI: note on 60 velocity 8000 channel 3 \(MIDI 2\.0\)")
    app.wait_log(r"HelloMIDI: from isim MIDI: note off 60 channel 3 \(MIDI 2\.0\)")
    app.send("midi send b0 07 40")
    app.wait_log(r"HelloMIDI: from isim MIDI: control 7 80000000")
    app.send("midi list")
    app.wait_log(r"source Monitor Out")
    # offline: the client hears it, and the device sends nothing
    app.send("midi offline")
    app.wait_log(r"HelloMIDI: property kMIDIPropertyOffline of isim MIDI")
    app.send("midi send 90 41 7f")
    app.wait_log(r"CoreMIDI: midi send: isim MIDI is offline")
    app.send("midi online")
    app.wait_log(r"CoreMIDI: isim MIDI is online")
    assert app.quit() == 0
