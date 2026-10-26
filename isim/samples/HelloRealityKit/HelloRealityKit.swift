// Sample: RealityKit without AR on isim (issue #331), drawn by isim's SceneKit renderer (Metal on the CPU). A SwiftUI
// RealityView holds a box spun by a custom System and Component, a physically based sphere, a mesh built from a
// MeshDescriptor with an unlit material, a crystal loaded from a Wavefront OBJ file, a ball falling onto the floor
// (physics and CollisionEvents), lights, a perspective camera and an entity moved by an animation. Below it, a non-AR
// ARView shows a second scene, with picking and projection. Progress goes to the log as "realitykit ..." lines, which
// tests/ui/test_realitykit.py reads.
import SwiftUI
import RealityKit
import UIKit

func log(_ s: String) { print("realitykit " + s) }

@main
struct HelloRealityKitApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup { ContentView() }
    }
}

/// a component and the system that spins the entities that have it
struct SpinComponent: Component {
    var speed: Float = .pi / 2
}
struct SpinSystem: System {
    static let query = EntityQuery(where: .has(SpinComponent.self))
    nonisolated(unsafe) static var frames = 0
    init(scene: RealityKit.Scene) {}
    func update(context: SceneUpdateContext) {
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let spin = e.components[SpinComponent.self] else { continue }
            e.orientation = simd_quatf(angle: spin.speed * Float(context.deltaTime), axis: [0, 1, 0]) * e.orientation
        }
        SpinSystem.frames += 1
        if SpinSystem.frames == 5 { log("system frames 5") }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("RealityKit on the CPU").font(.headline)
            RealityView { content in
                await build(&content)
            }
            .realityViewCameraControls(.orbit)
            .frame(height: 320)
            .background(Color(red: 0.55, green: 0.7, blue: 0.9))
            .accessibilityIdentifier("reality")
            ARViewPanel()
                .frame(width: 200, height: 160)
                .accessibilityIdentifier("arview")
            Spacer()
        }
        .padding()
    }

    @MainActor func build(_ content: inout RealityViewCameraContent) async {
        SpinComponent.registerComponent()
        SpinSystem.registerSystem()

        let floor = ModelEntity(mesh: .generatePlane(width: 8, depth: 8), materials: [SimpleMaterial(color: .lightGray, isMetallic: false)])
        floor.name = "floor"
        floor.collision = CollisionComponent(shapes: [.generateBox(width: 8, height: 0.02, depth: 8)])
        floor.physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static)
        content.add(floor)

        let box = ModelEntity(mesh: .generateBox(size: 0.5, cornerRadius: 0.02),
                              materials: [SimpleMaterial(color: .systemBlue, roughness: 0.3, isMetallic: false)])
        box.name = "box"
        box.position = [0, 0.25, 0]
        box.components.set(SpinComponent())
        content.add(box)

        var red = PhysicallyBasedMaterial()
        red.baseColor = .init(tint: .systemRed)
        red.metallic = 0.2
        red.roughness = 0.4
        red.emissiveColor = .init(color: UIColor(red: 0.2, green: 0, blue: 0, alpha: 1))
        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.3), materials: [red])
        sphere.name = "sphere"
        sphere.position = [-1, 0.3, 0.2]
        content.add(sphere)

        // a pyramid from a mesh descriptor, unlit
        var d = MeshDescriptor(name: "pyramid")
        d.positions = MeshBuffers.Positions([[-0.3, 0, 0.3], [0.3, 0, 0.3], [0.3, 0, -0.3], [-0.3, 0, -0.3], [0, 0.6, 0]])
        d.primitives = .triangles([0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 0, 3, 2, 0, 2, 1])
        if let mesh = try? MeshResource.generate(from: [d]) {
            let pyramid = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .systemYellow)])
            pyramid.name = "pyramid"
            pyramid.position = [1, 0, 0.2]
            content.add(pyramid)
            log("mesh bounds \(String(format: "%.1f", mesh.bounds.extents.y))")
        }

        // a crystal from a Wavefront OBJ file in the bundle
        if let crystal = try? Entity.load(named: "crystal") {
            crystal.position = [0, 1.2, -0.6]
            crystal.scale = [0.4, 0.4, 0.4]
            content.add(crystal)
            log("loaded \(crystal.name) children \(crystal.children.count) model \(crystal.children.first is ModelEntity)")
        }

        // a ball falling onto the floor
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.15), materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)],
                               collisionShape: .generateSphere(radius: 0.15), mass: 1)
        ball.name = "ball"
        ball.position = [0.7, 1.5, 0.8]
        content.add(ball)
        var reported = false
        _ = content.subscribe(to: CollisionEvents.Began.self, on: ball) { e in
            guard !reported else { return }
            reported = true
            log("collision \([e.entityA.name, e.entityB.name].sorted().joined(separator: " "))")
        }

        // lights and the camera
        let sun = DirectionalLight()
        sun.light.intensity = 1800
        sun.look(at: [0, 0, 0], from: [2, 4, 3], relativeTo: nil)
        content.add(sun)
        let lamp = PointLight()
        lamp.light = PointLightComponent(color: .orange, intensity: 20000, attenuationRadius: 6)
        lamp.position = [-1.5, 1.2, 1.2]
        content.add(lamp)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 50
        camera.look(at: [0, 0.3, 0], from: [0, 1.6, 3.2], relativeTo: nil)
        content.add(camera)

        // an animation: the sphere moves up, and the completion event arrives
        _ = content.subscribe(to: AnimationEvents.PlaybackCompleted.self) { e in
            log("animation done \(e.playbackController.entity?.name ?? "?") y \(String(format: "%.1f", e.playbackController.entity?.position.y ?? 0))")
        }
        var up = sphere.transform
        up.translation.y = 0.6
        sphere.move(to: up, relativeTo: sphere.parent, duration: 0.6, timingFunction: .easeInOut)

        let b = box.visualBounds(relativeTo: nil)
        log("content entities \(content.entities.count) box bounds \(String(format: "%.2f", b.extents.x)) found \(box.scene?.findEntity(named: "box") === box)")
    }
}

/// a non-AR ARView with a torus-like ring of spheres, and picking
struct ARViewPanel: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let v = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        v.environment.background = .color(UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1))
        let anchor = AnchorEntity(world: [0, 0, 0])
        let target = ModelEntity(mesh: .generateBox(size: 0.6), materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)])
        target.name = "target"
        target.orientation = simd_quatf(angle: .pi / 5, axis: [1, 1, 0])
        anchor.addChild(target)
        let cam = PerspectiveCamera()
        cam.look(at: .zero, from: [0, 0, 2], relativeTo: nil)
        anchor.addChild(cam)
        v.scene.anchors.append(anchor)
        log("arview anchors \(v.scene.anchors.count) mode nonAR \(v.cameraMode == .nonAR)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let center = CGPoint(x: v.bounds.midX, y: v.bounds.midY)
            log("arview entity \(v.entity(at: center)?.name ?? "none") project \(v.project([0, 0, 0]).map { "\(Int($0.x)),\(Int($0.y))" } ?? "nil")")
        }
        return v
    }
    func updateUIView(_ v: ARView, context: Context) {}
}
