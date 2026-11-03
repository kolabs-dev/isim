// BNNSGraph from Swift (issue #824): graphs built with BNNSGraph.Builder run on isim's graph engine through
// BNNSGraph.Context, with pointer and tensor arguments; compiled model files fail cleanly.
import Foundation
import Accelerate

func bnnsGraphChecks() {
    // y = sin(x) * 2 + c, with pointer arguments (outputs first)
    do {
        let ctx = try BNNSGraph.makeContext { builder in
            let x = builder.argument(name: "x", dataType: Float.self, shape: [4])
            let c = builder.constant(values: [1, 2, 3, 4] as [Float], shape: [4])
            let y = x.sin() * Float(2) + c
            return [y]
        }
        check(ctx.argumentCount() == 2 && ctx.argumentNames() == ["output_0", "x"] && ctx.argumentPosition(argument: "x") == 1
              && ctx.functionCount == 1, "BNNSGraph.makeContext: arguments are the outputs, then the inputs")
        var x: [Float] = [0, .pi / 2, .pi, -.pi / 2], y = [Float](repeating: 0, count: 4)
        try x.withUnsafeMutableBufferPointer { xp in
            try y.withUnsafeMutableBufferPointer { yp in try ctx.executeFunction(arguments: [yp, xp]) }
        }
        check(close(y, [1, 4, 3, 2], 1e-5), "BNNSGraph.Context.executeFunction with pointer arguments")
        let t = ctx.tensor(argument: "x", fillKnownDynamicShapes: true)
        check(t?.rank == 1 && t?.shape.0 == 4 && t?.data_type == .float, "BNNSGraph.Context.tensor(forFunction:argument:)")
    } catch { check(false, "BNNSGraph elementwise graph: \(error)") }

    // matmul + bias, softmax, reductions, argMax with tensor arguments
    do {
        let ctx = try BNNSGraph.makeContext { builder in
            let a = builder.argument(name: "a", dataType: Float.self, shape: [2, 3])
            let w = builder.constant(values: [1, 0, 0, 1, 1, 1] as [Float], shape: [3, 2])
            let m = a.matmul(other: w, bias: [10, 20] as [Float])
            return [m, m.softmax(axis: 1), a.sum(axes: [1], keepDimensions: false), a.argMax(axis: 1, keepDimension: false)]
        }
        var args: [BNNSTensor] = [
            ctx.allocateTensor(argument: "output_0", fillKnownDynamicShapes: true)!,
            ctx.allocateTensor(argument: "output_1", fillKnownDynamicShapes: true)!,
            ctx.allocateTensor(argument: "output_2", fillKnownDynamicShapes: true)!,
            ctx.allocateTensor(argument: "output_3", fillKnownDynamicShapes: true)!,
            BNNSTensor.allocate(initializingFrom: [1, 2, 3, 6, 5, 4] as [Float], shape: [2, 3], stride: [])]
        try ctx.executeFunction(arguments: &args)
        let m = args[0].makeArray(of: Float.self), sm = args[1].makeArray(of: Float.self)
        let sums = args[2].makeArray(of: Float.self), am = args[3].makeArray(of: Int32.self)
        func sig(_ d: Float) -> Double { Double(1 / (1 + Foundation.exp(-d))) }   /* softmax of two values d apart */
        check(m == [14, 25, 20, 29] && close(sm, [sig(-11), sig(11), sig(-9), sig(9)], 1e-5) && sums == [6, 15] && am == [2, 0],
              "BNNSGraph: matmul with bias, softmax, sum, argMax (tensor arguments)")
        for t in args { t.deallocate() }
    } catch { check(false, "BNNSGraph matmul graph: \(error)") }

    // convolution, pooling, reshape, transpose, slicing, concatenation, gather, topK, select
    do {
        let ctx = try BNNSGraph.makeContext { builder in
            let img = builder.argument(name: "img", dataType: Float.self, shape: [1, 1, 3, 3])
            let k = builder.constant(values: [1, 0, 0, -1] as [Float], shape: [1, 1, 2, 2])
            let c = img.conv(weight: k, strides: [1, 1], padding: .valid)
            let p = img.pooling(.max, kernelSize: [2, 2], strides: [1, 1], padding: .valid, ceilingMode: .floor)
            let flat = img.reshape(to: [3, 3])
            let tr = flat.transpose(axes: [1, 0])
            let row = flat[1, 0..<3]
            let cat = builder.concatenate([row, row], axis: 0)
            let g = row.gather(indices: [2, 0] as [Int32], axis: 0, batchDimensionCount: 0)
            let top = row.topK(2, axis: 0, findLargest: true)
            let sel = (row .> Float(4).graphBuilderTensor(builder)).select(row, Float(0))
            return [c, p, tr, cat, g, top.values, top.indices, sel]
        }
        let sizes = [4, 4, 9, 6, 2, 2, 2, 3]
        let bufs = sizes.map { n -> UnsafeMutableBufferPointer<Float> in
            let p = UnsafeMutableBufferPointer<Float>.allocate(capacity: n); p.initialize(repeating: -1); return p
        }
        let img = UnsafeMutableBufferPointer<Float>.allocate(capacity: 9)
        for k in 0..<9 { img[k] = Float(k + 1) }
        defer { bufs.forEach { $0.deallocate() }; img.deallocate() }
        try ctx.executeFunction(arguments: bufs + [img])   /* output 6 (Int32 indices) shares the 4-byte element size */
        let outs = bufs.map { Array($0) }
        let idx = UnsafeRawBufferPointer(bufs[6]).bindMemory(to: Int32.self).map { $0 }
        check(outs[0] == [-4, -4, -4, -4] && outs[1] == [5, 6, 8, 9], "BNNSGraph: conv and max pooling")
        check(outs[2] == [1, 4, 7, 2, 5, 8, 3, 6, 9] && outs[3] == [4, 5, 6, 4, 5, 6] && outs[4] == [6, 4], "BNNSGraph: transpose, slicing, concatenate, gather")
        check(outs[5] == [6, 5] && idx == [2, 1] && outs[7] == [0, 5, 6], "BNNSGraph: topK and select")
    } catch { check(false, "BNNSGraph layer graph: \(error)") }

    // an LSTM step against a hand computation, and layer norm
    do {
        let ctx = try BNNSGraph.makeContext { builder in
            let x = builder.argument(name: "x", dataType: Float.self, shape: [1, 1, 1])
            let h0 = builder.constant(values: [0] as [Float], shape: [1, 1]), c0 = builder.constant(values: [0] as [Float], shape: [1, 1])
            let wih = builder.constant(values: [1, 1, 1, 1] as [Float], shape: [4, 1]), whh = builder.constant(values: [0, 0, 0, 0] as [Float], shape: [4, 1])
            let b = builder.constant(values: [0, 0, 0, 0] as [Float], shape: [4])
            let r = x.lstm(initialHiddenStates: h0, initialCellStates: c0, inputHiddenWeight: wih, hiddenHiddenWeight: whh, bias: b, direction: .forward,
                           activation: .tanh, recurrentActivation: .sigmoid, cellActivation: .tanh, outputSequence: true)
            let ln = builder.constant(values: [1, 2, 3, 4] as [Float], shape: [1, 4]).layerNorm(axes: [1], epsilon: 0)
            return [r.hiddenStates, r.memoryStates, ln]
        }
        var x: [Float] = [1], h = [Float](repeating: 0, count: 1), c = [Float](repeating: 0, count: 1), ln = [Float](repeating: 0, count: 4)
        try x.withUnsafeMutableBufferPointer { xp in try h.withUnsafeMutableBufferPointer { hp in try c.withUnsafeMutableBufferPointer { cp in
            try ln.withUnsafeMutableBufferPointer { lp in try ctx.executeFunction(arguments: [hp, cp, lp, xp]) }
        } } }
        let s = 1 / (1 + Foundation.exp(Float(-1))), cc = s * Foundation.tanh(Float(1)), hh = s * Foundation.tanh(cc)
        check(close(c, [Double(cc)], 1e-5) && close(h, [Double(hh)], 1e-5), "BNNSGraph: LSTM step (gates i, f, o, g)")
        let sd = Float(1.25).squareRoot()
        check(close(ln, [Double(-1.5 / sd), Double(-0.5 / sd), Double(0.5 / sd), Double(1.5 / sd)], 1e-5), "BNNSGraph: layerNorm")
    } catch { check(false, "BNNSGraph recurrent graph: \(error)") }

    // more operations: cumulative sum, argSort, pad, scatter, cast, norms, prelu, RNN / GRU, dynamic reshape, comparisons
    do {
        let ctx = try BNNSGraph.makeContext { builder in
            let v = builder.argument(name: "v", dataType: Float.self, shape: [4])
            let cs = v.cumulativeSum(axis: 0)
            let order = v.argSort(axis: 0, sortOrder: .ascending)
            let padded = v.pad(.constant(value: 9), padding: [1, 2])
            let sc = v.scatter(updates: builder.constant(values: [100, 200] as [Float], shape: [2]), indices: [0, 3] as [Int32], mode: .add, axis: 0)
            let asInt = v.cast(to: Int32.self)
            let m = v.reshape(to: [1, 4, 1, 1])
            let bn = m.batchNorm(mean: [1, 1, 1, 1] as [Float], variance: [4, 4, 4, 4] as [Float], epsilon: 0)
            let rms = v.reshape(to: [1, 4]).rmsNorm(scale: [1, 1, 1, 1] as [Float], epsilon: 0)
            let pr = (v - Float(3)).reshape(to: [1, 4]).prelu(alpha: [0.5])
            let seq = v.reshape(to: [4, 1, 1])
            let h0 = builder.constant(values: [0] as [Float], shape: [1, 1])
            let rnn = seq.rnn(initialHiddenStates: h0, inputHiddenWeight: builder.constant(values: [1] as [Float], shape: [1, 1]),
                              hiddenHiddenWeight: builder.constant(values: [1] as [Float], shape: [1, 1]), bias: builder.constant(values: [0] as [Float], shape: [1]),
                              direction: .forward, activation: .linear, outputSequence: false)
            let gru = seq.gru(initialHiddenStates: h0, inputHiddenWeight: builder.constant(values: [0, 0, 0] as [Float], shape: [3, 1]),
                              hiddenHiddenWeight: builder.constant(values: [0, 0, 0] as [Float], shape: [3, 1]),
                              bias: builder.constant(values: [0, 0, 0] as [Float], shape: [3]), inputBias: builder.constant(values: [0, 0, 0] as [Float], shape: [3]),
                              direction: .forward, activation: .tanh, recurrentActivation: .sigmoid, applyResetGateAfterMatMul: true, outputSequence: false)
            let dyn = v.reshape(to: builder.constant(values: [2, 2] as [Int32], shape: [2]))
            let ge = (v .>= builder.constant(values: [2, 2, 2, 2] as [Float], shape: [4])).cast(to: Float.self)
            return [cs, order.cast(to: Float.self), padded, sc, asInt.cast(to: Float.self), bn.reshape(to: [4]), rms.reshape(to: [4]),
                    pr.reshape(to: [4]), rnn.hiddenStates.reshape(to: [1]), gru.hiddenStates.reshape(to: [1]), dyn.reshape(to: [4]), ge,
                    v.mean(axes: [0], keepDimensions: false), v.maximum(axes: [0], keepDimensions: true)]
        }
        let sizes = [4, 4, 7, 4, 4, 4, 4, 4, 1, 1, 4, 4, 1, 1]
        let bufs = sizes.map { n -> UnsafeMutableBufferPointer<Float> in
            let p = UnsafeMutableBufferPointer<Float>.allocate(capacity: n); p.initialize(repeating: -1); return p
        }
        let v = UnsafeMutableBufferPointer<Float>.allocate(capacity: 4)
        for (k, x) in [3.5, 1, 4, 2].enumerated() { v[k] = Float(x) }
        defer { bufs.forEach { $0.deallocate() }; v.deallocate() }
        try ctx.executeFunction(arguments: bufs + [v])
        let o = bufs.map { Array($0) }
        check(o[0] == [3.5, 4.5, 8.5, 10.5] && o[1] == [1, 3, 0, 2] && o[2] == [9, 3.5, 1, 4, 2, 9, 9] && o[3] == [103.5, 1, 4, 202],
              "BNNSGraph: cumulativeSum, argSort, pad, scatter")
        let rmsD = Double(((3.5 * 3.5 + 1 + 16 + 4) / 4.0).squareRoot())
        check(o[4] == [3, 1, 4, 2] && close(o[5], [1.25, 0, 1.5, 0.5], 1e-6) && close(o[6], [3.5 / rmsD, 1 / rmsD, 4 / rmsD, 2 / rmsD], 1e-5)
              && o[7] == [0.5, -1, 1, -0.5], "BNNSGraph: cast, batchNorm, rmsNorm, prelu")
        check(o[8] == [10.5] && o[9] == [0] && o[10] == [3.5, 1, 4, 2] && o[11] == [1, 0, 1, 1] && o[12] == [2.625] && o[13] == [4],
              "BNNSGraph: RNN, GRU, dynamic reshape, comparison, mean, maximum")
    } catch { check(false, "BNNSGraph operations graph: \(error)") }

    // compiled models: not readable on isim
    do {
        _ = try BNNSGraph.Context(compileFromPath: "/nonexistent/model.mlmodelc")
        check(false, "BNNSGraph.Context(compileFromPath:) should throw")
    } catch BNNSGraph.Error.unableToCreateGraph {
        check(true, "BNNSGraph.Context(compileFromPath:): Apple's compiled models are not readable (throws)")
    } catch { check(false, "BNNSGraph.Context(compileFromPath:): \(error)") }
    let opts = BNNSGraph.CompileOptions(useSingleThread: true, generateDebugInfo: false, optimizationPreference: .internalRepresentationSize)
    check(opts.useSingleThread && opts.optimizationPreference == .internalRepresentationSize && BNNSGraph.Shape([2, 3]).dimensions == [2, 3],
          "BNNSGraph.CompileOptions, BNNSGraph.Shape")
}
