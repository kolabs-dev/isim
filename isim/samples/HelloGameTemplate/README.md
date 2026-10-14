# HelloGameTemplate

Xcode's iOS **Game** template (SpriteKit with GameplayKit) on isim: `GameViewController` loads `GameScene.sks` with
`GKScene(fileNamed:)`, hands the scene its entities and graphs and presents its root node, an `SKScene` subclass the
file names. `GameScene` finds the "Hello, World!" label, fades it in, and where the screen is touched pulses the label
with the "Pulse" action from `Actions.sks` (`SKAction(named:)`) and spins a shape.

`GameScene.sks` and `Actions.sks` were made by Xcode's scene and action editors and are unmodified. They come from
Apple's HelloGameKit sample code (Copyright (C) 2016 Apple Inc.) and are redistributed under the license in
`LICENSE-Apple-sample.txt`. They are the real file formats isim's .sks reader has to understand (issue #225); the
Swift sources here are isim's own.
