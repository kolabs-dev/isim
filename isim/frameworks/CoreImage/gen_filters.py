#!/usr/bin/env python3
"""The built-in Core Image filters: names, categories, iOS availability, inputs (key, class, attribute type, default,
range) and the typed CIFilterBuiltins accessors. Generates

  isim/sdk-src/Frameworks/CoreImage/CIFilterBuiltins.h   (protocols and +[CIFilter xxxFilter] factories)
  isim/frameworks/CoreImage/CIFilterSpec.inc              (the registry the framework reads)

Run it after editing the table; tests/host/test_coreimage_spec.py checks that both outputs are current.
The implementations live in the CIFilters*.m files (ci_register_impl)."""
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
HEADER = os.path.join(ROOT, "..", "..", "sdk-src", "Frameworks", "CoreImage", "CIFilterBuiltins.h")
SPEC = os.path.join(ROOT, "CIFilterSpec.inc")

PI = math.pi


# ---- inputs ----
class In:
    def __init__(self, key, cls, atype, default=None, mn=None, mx=None, smin=None, smax=None, ident=None, prop=None, ptype=None):
        self.key, self.cls, self.atype, self.default = key, cls, atype, default
        self.mn, self.mx, self.smin, self.smax, self.ident = mn, mx, smin, smax, ident
        self.prop = prop if prop is not None else prop_name(key)
        self.ptype = ptype if ptype is not None else default_ptype(cls, atype)


def prop_name(key):
    k = key[5:] if key.startswith("input") else key
    if k in ("EV",) or k.startswith("NR") or k.isupper():
        return k
    return k[0].lower() + k[1:]


def default_ptype(cls, atype):
    if cls == "NSNumber":
        return "BOOL" if atype == "Boolean" else "float"
    if cls == "CIVector":
        return {"Position": "CGPoint", "Offset": "CGPoint", "Rectangle": "CGRect"}.get(atype, "CIVector *")
    if cls == "NSValue":
        return "CGAffineTransform"
    if cls == "CGColorSpace":
        return "CGColorSpaceRef"
    return cls + " *"


def img(key="inputImage", prop=None, atype="Image"):
    return In(key, "CIImage", atype, prop=prop if prop is not None else ("inputImage" if key == "inputImage" else None))


def num(key, default, mn=None, mx=None, smin=None, smax=None, atype="Scalar", ident=None, ptype=None, prop=None):
    return In(key, "NSNumber", atype, default, mn, mx, smin if smin is not None else mn, smax if smax is not None else mx,
              ident if ident is not None else default, prop=prop, ptype=ptype)


def boolean(key, default, prop=None):
    return In(key, "NSNumber", "Boolean", 1 if default else 0, 0, 1, 0, 1, 1 if default else 0, prop=prop)


def vec(key, default, atype="", ident=None, ptype=None, prop=None):
    return In(key, "CIVector", atype, tuple(default), ident=ident if ident is not None else tuple(default), ptype=ptype, prop=prop)


def point(key, default, prop=None):
    return vec(key, default, "Position", prop=prop)


def rect(key, default, prop=None):
    return vec(key, default, "Rectangle", prop=prop)


def color(key, default, opaque=False, prop=None):
    rgba = tuple(default) + ((1.0,) if len(default) == 3 else ())
    return In(key, "CIColor", "OpaqueColor" if opaque else "Color", rgba, ident=rgba, prop=prop)


def data(key, prop=None, default=None):
    return In(key, "NSData", "", default, prop=prop)


def string(key, default, prop=None):
    return In(key, "NSString", "", default, prop=prop)


def obj(key, cls, prop=None, ptype=None, default=None):
    return In(key, cls, "", default, prop=prop, ptype=ptype)


def xform(key="inputTransform"):
    return In(key, "NSValue", "Transform", "identity", ident="identity")


def colorspace(key="inputColorSpace", default=None):
    return In(key, "CGColorSpace", "", default)


CENTER = point("inputCenter", (150, 150))
ANGLE0 = num("inputAngle", 0, -PI, PI, atype="Angle")
TIME = num("inputTime", 0, 0, 1, atype="Time")


# ---- filters ----
class F:
    def __init__(self, name, cats, inputs, ios=8, proto=None, factory=None, swift=None, builtin=True, base=None, video=True):
        self.name, self.inputs, self.ios = name, inputs, ios
        self.cats = cats
        self.video = video
        self.proto = proto or name
        self.base = base
        self.builtin = builtin
        stem = name[2:]
        self.factory = factory or (stem[0].lower() + stem[1:] + "Filter")
        if swift:
            self.swift = swift
        else:
            s = self.factory[:-6] if self.factory.endswith("Filter") else self.factory
            self.swift = s[0].lower() + s[1:]


FILTERS = []


def f(*a, **k):
    FILTERS.append(F(*a, **k))


I = img()
BG = img("inputBackgroundImage")
MASK = img("inputMaskImage", prop="maskImage")
TARGET = img("inputTargetImage")

# -- blur --
f("CIBokehBlur", "Blur", [I, num("inputRadius", 20, 0, 500, 0, 35, "Distance"), num("inputRingAmount", 0, 0, 1),
                          num("inputRingSize", 0.1, 0, 0.2), num("inputSoftness", 1, 0, 10)], ios=10)
f("CIBoxBlur", "Blur", [I, num("inputRadius", 10, 1, 100, atype="Distance")], ios=9)
f("CIDepthBlurEffect", "Blur", [I, img("inputDisparityImage"), img("inputMatteImage"), img("inputHairImage"), img("inputGlassesImage"),
                                img("inputGainMap"), num("inputAperture", 0, 0, 22), vec("inputLeftEyePositions", (-1, -1, -1, -1)),
                                vec("inputRightEyePositions", (-1, -1, -1, -1)), vec("inputChinPositions", (-1, -1, -1, -1)),
                                vec("inputNosePositions", (-1, -1, -1, -1)), rect("inputFocusRect", (0, 0, 0, 0)),
                                num("inputLumaNoiseScale", 0, 0, 0.1), num("inputScaleFactor", 1, 0, 1),
                                obj("inputCalibrationData", "NSObject"), obj("inputAuxDataMetadata", "NSDictionary"),
                                string("inputShape", "")], ios=12, builtin=False)
f("CIDiscBlur", "Blur", [I, num("inputRadius", 8, 0, 100, atype="Distance")], ios=9)
f("CIGaussianBlur", "Blur", [I, num("inputRadius", 10, 0, 100, atype="Distance")], ios=6)
f("CIMaskedVariableBlur", "Blur", [I, img("inputMask", prop="mask"), num("inputRadius", 5, 0, 100, atype="Distance")], ios=8)
f("CIMedianFilter", "Blur", [I], ios=9, factory="medianFilter", swift="median", proto="CIMedian")
f("CIMorphologyGradient", "Blur", [I, num("inputRadius", 5, 0, 50, atype="Distance")], ios=11)
f("CIMorphologyMaximum", "Blur", [I, num("inputRadius", 0, 0, 50, atype="Distance")], ios=11)
f("CIMorphologyMinimum", "Blur", [I, num("inputRadius", 0, 0, 50, atype="Distance")], ios=11)
f("CIMorphologyRectangleMaximum", "Blur", [I, num("inputWidth", 5, 1, 50, atype="Distance"), num("inputHeight", 5, 1, 50, atype="Distance")], ios=11)
f("CIMorphologyRectangleMinimum", "Blur", [I, num("inputWidth", 5, 1, 50, atype="Distance"), num("inputHeight", 5, 1, 50, atype="Distance")], ios=11)
f("CIMotionBlur", "Blur", [I, num("inputRadius", 20, 0, 100, atype="Distance"), ANGLE0], ios=8)
f("CINoiseReduction", "Blur", [I, num("inputNoiseLevel", 0.02, 0, 0.1), num("inputSharpness", 0.4, 0, 2)], ios=9)
f("CIZoomBlur", "Blur", [I, CENTER, num("inputAmount", 20, 0, 200, atype="Distance")], ios=8.3)

# -- color adjustment --
f("CIColorClamp", "ColorAdjustment", [I, vec("inputMinComponents", (0, 0, 0, 0)), vec("inputMaxComponents", (1, 1, 1, 1))], ios=7)
f("CIColorControls", "ColorAdjustment", [I, num("inputSaturation", 1, 0, 2), num("inputBrightness", 0, -1, 1),
                                         num("inputContrast", 1, 0.25, 4)], ios=5)
f("CIColorMatrix", "ColorAdjustment", [I, vec("inputRVector", (1, 0, 0, 0), prop="RVector"), vec("inputGVector", (0, 1, 0, 0), prop="GVector"),
                                       vec("inputBVector", (0, 0, 1, 0), prop="BVector"), vec("inputAVector", (0, 0, 0, 1), prop="AVector"),
                                       vec("inputBiasVector", (0, 0, 0, 0))], ios=5)
f("CIColorPolynomial", "ColorAdjustment", [I, vec("inputRedCoefficients", (0, 1, 0, 0)), vec("inputGreenCoefficients", (0, 1, 0, 0)),
                                           vec("inputBlueCoefficients", (0, 1, 0, 0)), vec("inputAlphaCoefficients", (0, 1, 0, 0))], ios=7)
f("CIDepthToDisparity", "ColorAdjustment", [I], ios=11)
f("CIDisparityToDepth", "ColorAdjustment", [I], ios=11)
f("CIExposureAdjust", "ColorAdjustment", [I, num("inputEV", 0, -10, 10, prop="EV")], ios=5)
f("CIGammaAdjust", "ColorAdjustment", [I, num("inputPower", 1, 0.25, 4)], ios=5)
f("CIHueAdjust", "ColorAdjustment", [I, ANGLE0], ios=5)
f("CILinearToSRGBToneCurve", "ColorAdjustment", [I], ios=7, factory="linearToSRGBToneCurveFilter")
f("CISRGBToneCurveToLinear", "ColorAdjustment", [I], ios=7, factory="sRGBToneCurveToLinearFilter", swift="sRGBToneCurveToLinear")
f("CITemperatureAndTint", "ColorAdjustment", [I, vec("inputNeutral", (6500, 0), "Offset", ptype="CIVector *"),
                                              vec("inputTargetNeutral", (6500, 0), "Offset", ptype="CIVector *")], ios=5)
f("CIToneCurve", "ColorAdjustment", [I, point("inputPoint0", (0, 0)), point("inputPoint1", (0.25, 0.25)), point("inputPoint2", (0.5, 0.5)),
                                     point("inputPoint3", (0.75, 0.75)), point("inputPoint4", (1, 1)), boolean("inputExtrapolate", False)], ios=5)
f("CIVibrance", "ColorAdjustment", [I, num("inputAmount", 0, -1, 1)], ios=5)
f("CIWhitePointAdjust", "ColorAdjustment", [I, color("inputColor", (1, 1, 1))], ios=5)
f("CIColorAbsoluteDifference", "ColorAdjustment", [I, img("inputImage2", prop="inputImage2")], ios=14)
f("CIColorThreshold", "ColorAdjustment", [I, num("inputThreshold", 0.5, 0, 1)], ios=14)
f("CIColorThresholdOtsu", "ColorAdjustment", [I], ios=14)
f("CIToneMapHeadroom", "ColorAdjustment", [I, num("inputSourceHeadroom", 1, 0.1, 16), num("inputTargetHeadroom", 1, 0.1, 16)], ios=18)
f("CISystemToneMap", "ColorAdjustment", [I, num("inputDisplayHeadroom", 1, 1, 16),
                                         obj("inputPreferredDynamicRange", "NSString", ptype="CIDynamicRangeOption")], ios=26)

# -- color effect --
f("CIColorCrossPolynomial", "ColorEffect", [I, vec("inputRedCoefficients", (1, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                                            vec("inputGreenCoefficients", (0, 1, 0, 0, 0, 0, 0, 0, 0, 0)),
                                            vec("inputBlueCoefficients", (0, 0, 1, 0, 0, 0, 0, 0, 0, 0))], ios=7)
f("CIColorCube", "ColorEffect", [I, num("inputCubeDimension", 2, 2, 128, atype="Count"), data("inputCubeData"), boolean("inputExtrapolate", False)], ios=5)
f("CIColorCubeWithColorSpace", "ColorEffect", [I, num("inputCubeDimension", 2, 2, 128, atype="Count"), data("inputCubeData"),
                                               boolean("inputExtrapolate", False), colorspace()], ios=7)
f("CIColorCubesMixedWithMask", "ColorEffect", [I, img("inputMaskImage", prop="maskImage"), num("inputCubeDimension", 2, 2, 128, atype="Count"),
                                               data("inputCube0Data"), data("inputCube1Data"), colorspace(), boolean("inputExtrapolate", False)], ios=11)
f("CIColorCurves", "ColorEffect", [I, data("inputCurvesData"), vec("inputCurvesDomain", (0, 1)), colorspace()], ios=11)
f("CIColorInvert", "ColorEffect", [I], ios=5)
f("CIColorMap", "ColorEffect", [I, img("inputGradientImage", atype="Gradient")], ios=6)
f("CIColorMonochrome", "ColorEffect", [I, color("inputColor", (0.6, 0.45, 0.3), opaque=True), num("inputIntensity", 1, 0, 1)], ios=5)
f("CIColorPosterize", "ColorEffect", [I, num("inputLevels", 6, 2, 30)], ios=6)
f("CIConvertLabToRGB", "ColorEffect", [I, boolean("inputNormalize", False)], ios=16, factory="convertLabToRGBFilter", swift="convertLabToRGB",
  proto="CIConvertLab")
f("CIConvertRGBtoLab", "ColorEffect", [I, boolean("inputNormalize", False)], ios=16, factory="convertRGBtoLabFilter", swift="convertRGBtoLab",
  proto="CIConvertLab")
f("CIDither", "ColorEffect", [I, num("inputIntensity", 0.1, 0, 5, 0, 0.5)], ios=12)
f("CIDocumentEnhancer", "ColorEffect", [I, num("inputAmount", 1, 0, 10)], ios=12)
f("CIFalseColor", "ColorEffect", [I, color("inputColor0", (0.3, 0, 0)), color("inputColor1", (1, 0.9, 0.8))], ios=5)
f("CILabDeltaE", "ColorEffect", [I, img("inputImage2", prop="image2")], ios=12, factory="LabDeltaEFilter", swift="labDeltaE")
f("CIMaskToAlpha", "ColorEffect", [I], ios=6)
f("CIMaximumComponent", "ColorEffect", [I], ios=6)
f("CIMinimumComponent", "ColorEffect", [I], ios=6)
f("CIPaletteCentroid", "ColorEffect", [I, img("inputPaletteImage"), boolean("inputPerceptual", False)], ios=12)
f("CIPalettize", "ColorEffect", [I, img("inputPaletteImage"), boolean("inputPerceptual", False)], ios=12)
for e in ("Chrome", "Fade", "Instant", "Mono", "Noir", "Process", "Tonal", "Transfer"):
    f(f"CIPhotoEffect{e}", "ColorEffect", [I, boolean("inputExtrapolate", False)], ios=7, proto="CIPhotoEffect")
f("CISepiaTone", "ColorEffect", [I, num("inputIntensity", 1, 0, 1)], ios=5)
f("CIThermal", "ColorEffect", [I], ios=12)
f("CIVignette", "ColorEffect", [I, num("inputIntensity", 0, -1, 1), num("inputRadius", 1, 0, 2)], ios=5)
f("CIVignetteEffect", "ColorEffect", [I, CENTER, num("inputRadius", 150, 0, 2000, 0, 1000, "Distance"), num("inputIntensity", 1, -1, 1),
                                      num("inputFalloff", 0.5, 0, 1)], ios=7)
f("CIXRay", "ColorEffect", [I], ios=12, factory="xRayFilter", swift="xRay")

# -- composite --
for n, ios in (("CIAdditionCompositing", 5), ("CIColorBlendMode", 5), ("CIColorBurnBlendMode", 5), ("CIColorDodgeBlendMode", 5),
               ("CIDarkenBlendMode", 5), ("CIDifferenceBlendMode", 5), ("CIDivideBlendMode", 8), ("CIExclusionBlendMode", 5),
               ("CIHardLightBlendMode", 5), ("CIHueBlendMode", 5), ("CILightenBlendMode", 5), ("CILinearBurnBlendMode", 8),
               ("CILinearDodgeBlendMode", 8), ("CILinearLightBlendMode", 15), ("CILuminosityBlendMode", 5), ("CIMaximumCompositing", 5),
               ("CIMinimumCompositing", 5), ("CIMultiplyBlendMode", 5), ("CIMultiplyCompositing", 5), ("CIOverlayBlendMode", 5),
               ("CIPinLightBlendMode", 8), ("CISaturationBlendMode", 5), ("CIScreenBlendMode", 5), ("CISoftLightBlendMode", 5),
               ("CISourceAtopCompositing", 5), ("CISourceInCompositing", 5), ("CISourceOutCompositing", 5), ("CISourceOverCompositing", 5),
               ("CISubtractBlendMode", 8), ("CIVividLightBlendMode", 15)):
    f(n, "CompositeOperation", [I, BG], ios=ios, proto="CICompositeOperation")

# -- distortion --
f("CIBumpDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 300, 0, 600, atype="Distance"), num("inputScale", 0.5, -1, 1)], ios=6)
f("CIBumpDistortionLinear", "DistortionEffect", [I, point("inputCenter", (300, 300)), num("inputRadius", 300, 0, 600, atype="Distance"),
                                                 ANGLE0, num("inputScale", 0.5, -1, 1)], ios=6)
f("CICircleSplashDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 150, 0, 1000, atype="Distance")], ios=6)
f("CICircularWrap", "DistortionEffect", [I, CENTER, num("inputRadius", 150, 0, 600, atype="Distance"), ANGLE0], ios=6)
f("CIDisplacementDistortion", "DistortionEffect", [I, img("inputDisplacementImage"), num("inputScale", 50, 0, 200, atype="Distance")], ios=9)
f("CIDroste", "DistortionEffect", [I, point("inputInsetPoint0", (200, 200)), point("inputInsetPoint1", (400, 400)), num("inputStrands", 1, -10, 10, -2, 2),
                                   num("inputPeriodicity", 1, 1, 5, 1, 5), num("inputRotation", 0, 0, 2 * PI, atype="Angle"), num("inputZoom", 1, 0.01, 5)], ios=9)
f("CIGlassDistortion", "DistortionEffect", [I, img("inputTexture", prop="textureImage"), CENTER, num("inputScale", 200, 0.001, 1000, 0.001, 500, "Distance")], ios=8)
f("CIGlassLozenge", "DistortionEffect", [I, point("inputPoint0", (150, 150)), point("inputPoint1", (350, 150)),
                                         num("inputRadius", 100, 0, 1000, 0, 400, "Distance"), num("inputRefraction", 1.7, 0, 5)], ios=9)
f("CIHoleDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 150, 0.01, 1000, atype="Distance")], ios=6)
f("CILightTunnel", "DistortionEffect", [I, CENTER, num("inputRotation", 0, -2 * PI, 2 * PI, atype="Angle"), num("inputRadius", 100, 1, 500, atype="Distance")], ios=6)
f("CINinePartStretched", "DistortionEffect", [I, point("inputBreakpoint0", (50, 50)), point("inputBreakpoint1", (150, 150)),
                                              vec("inputGrowAmount", (100, 100), "Offset")], ios=10)
f("CINinePartTiled", "DistortionEffect", [I, point("inputBreakpoint0", (50, 50)), point("inputBreakpoint1", (150, 150)),
                                          vec("inputGrowAmount", (100, 100), "Offset"), boolean("inputFlipYTiles", True)], ios=10)
f("CIPinchDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 300, 0, 1000, atype="Distance"), num("inputScale", 0.5, 0, 2)], ios=6)
f("CIStretchCrop", "DistortionEffect", [I, vec("inputSize", (1280, 720), "Position"), num("inputCropAmount", 0.25, 0, 1),
                                        num("inputCenterStretchAmount", 0.25, 0, 1)], ios=9)
f("CITorusLensDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 160, 0, 1000, 0, 500, "Distance"),
                                                num("inputWidth", 80, 0, 500, 0, 200, "Distance"), num("inputRefraction", 1.7, 0, 5)], ios=9)
f("CITwirlDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 300, 0, 1000, 0, 500, "Distance"),
                                            num("inputAngle", PI, -4 * PI, 4 * PI, atype="Angle")], ios=6)
f("CIVortexDistortion", "DistortionEffect", [I, CENTER, num("inputRadius", 300, 0, 1000, 0, 800, "Distance"),
                                             num("inputAngle", 56.55, -94.25, 94.25, atype="Angle")], ios=6)

# -- generators --
f("CIAttributedTextImageGenerator", "Generator", [obj("inputText", "NSAttributedString", prop="text"), num("inputScaleFactor", 1, 0, 50, 1, 4),
                                                  num("inputPadding", 0, 0, 200, 0, 100)], ios=11)
f("CIAztecCodeGenerator", "Generator", [data("inputMessage"), num("inputCorrectionLevel", 23, 5, 95), num("inputLayers", None, 1, 32),
                                        num("inputCompactStyle", None, 0, 1, atype="Boolean", ptype="float")], ios=8, factory="aztecCodeGenerator", video=False)
f("CIBarcodeGenerator", "Generator", [obj("inputBarcodeDescriptor", "CIBarcodeDescriptor")], ios=11, factory="barcodeGenerator", video=False)
f("CICheckerboardGenerator", "Generator", [CENTER, color("inputColor0", (1, 1, 1)), color("inputColor1", (0, 0, 0)),
                                           num("inputWidth", 80, 0, 800, atype="Distance"), num("inputSharpness", 1, 0, 1)], ios=5)
f("CICode128BarcodeGenerator", "Generator", [data("inputMessage"), num("inputQuietSpace", 7, 0, 100, 0, 20),
                                             num("inputBarcodeHeight", 32, 1, 500)], ios=8, factory="code128BarcodeGenerator", video=False)
f("CIConstantColorGenerator", "Generator", [color("inputColor", (1, 0, 0))], ios=5)
f("CILenticularHaloGenerator", "Generator", [CENTER, color("inputColor", (1, 0.9, 0.8)), num("inputHaloRadius", 70, 0, 1000, 0, 1000, "Distance"),
                                             num("inputHaloWidth", 87, 0, 300, 0, 300, "Distance"), num("inputHaloOverlap", 0.77, 0, 1),
                                             num("inputStriationStrength", 0.5, 0, 3), num("inputStriationContrast", 1, 0, 5), num("inputTime", 0, 0, 1)], ios=9)
f("CIMeshGenerator", "Generator", [num("inputWidth", 1.5, 0, 200, 0, 20, "Distance"), color("inputColor", (1, 1, 1)), obj("inputMesh", "NSArray")], ios=9)
f("CIPDF417BarcodeGenerator", "Generator", [data("inputMessage"), num("inputMinWidth", None, 56, 583), num("inputMaxWidth", None, 56, 583),
                                            num("inputMinHeight", None, 13, 283), num("inputMaxHeight", None, 13, 283),
                                            num("inputDataColumns", None, 1, 30, atype="Integer"), num("inputRows", None, 3, 90, atype="Integer"),
                                            num("inputPreferredAspectRatio", None, 0), num("inputCompactionMode", None, 0, 3, atype="Integer"),
                                            num("inputCompactStyle", None, 0, 1, atype="Boolean", ptype="float"),
                                            num("inputCorrectionLevel", None, 0, 8, atype="Integer"),
                                            num("inputAlwaysSpecifyCompaction", None, 0, 1, atype="Boolean", ptype="float")],
  ios=9, factory="PDF417BarcodeGenerator", swift="pdf417BarcodeGenerator", video=False)
f("CIQRCodeGenerator", "Generator", [data("inputMessage"), string("inputCorrectionLevel", "M")], ios=7, factory="QRCodeGenerator",
  swift="qrCodeGenerator", video=False)
f("CIRandomGenerator", "Generator", [], ios=6)
f("CIRoundedQRCodeGenerator", "Generator", [data("inputMessage"), string("inputCorrectionLevel", "M"), num("inputScale", 10, 1, 100, 1, 20),
                                            color("inputColor0", (0, 0, 0), opaque=True), color("inputColor1", (1, 1, 1), opaque=True),
                                            num("inputRoundedMarkers", 0, 0, 3, atype="Integer", ptype="NSInteger"), boolean("inputRoundedData", True),
                                            num("inputCenterSpaceSize", 0, 0, 0.5)], ios=26, factory="roundedQRCodeGenerator",
  swift="roundedQRCodeGenerator", video=False)
f("CIRoundedRectangleGenerator", "Generator", [rect("inputExtent", (0, 0, 100, 100)), num("inputRadius", 10, 0, 1000, 0, 100, "Distance"),
                                               color("inputColor", (1, 1, 1)), num("inputSmoothness", 0, 0, 1)], ios=13)
f("CIRoundedRectangleStrokeGenerator", "Generator", [rect("inputExtent", (0, 0, 100, 100)), num("inputRadius", 10, 0, 1000, 0, 100, "Distance"),
                                                     color("inputColor", (1, 1, 1)), num("inputWidth", 10, 0, 1000, 0, 100, "Distance"),
                                                     num("inputSmoothness", 0, 0, 1)], ios=17)
f("CIBlurredRoundedRectangleGenerator", "Generator", [rect("inputExtent", (0, 0, 100, 100)), num("inputRadius", 10, 0, 1000, 0, 100, "Distance"),
                                                      num("inputSigma", 10, 0, 1000, 0, 100, "Distance"), color("inputColor", (1, 1, 1)),
                                                      num("inputSmoothness", 0, 0, 1)], ios=26)
f("CIBlurredRectangleGenerator", "Generator", [rect("inputExtent", (0, 0, 100, 100)), num("inputSigma", 10, 0, 1000, 0, 100, "Distance"),
                                               color("inputColor", (1, 1, 1))], ios=17)
f("CIStarShineGenerator", "Generator", [CENTER, color("inputColor", (1, 0.8, 0.6)), num("inputRadius", 50, 0, 1000, 0, 300, "Distance"),
                                        num("inputCrossScale", 15, 0, 100, 0, 100), num("inputCrossAngle", 0.6, -PI, PI, atype="Angle"),
                                        num("inputCrossOpacity", -2, -8, 0), num("inputCrossWidth", 2.5, 0, 300, 0, 300, "Distance"),
                                        num("inputEpsilon", -2, -8, 0)], ios=9)
f("CIStripesGenerator", "Generator", [CENTER, color("inputColor0", (1, 1, 1)), color("inputColor1", (0, 0, 0)),
                                      num("inputWidth", 80, 0, 800, atype="Distance"), num("inputSharpness", 1, 0, 1)], ios=5)
f("CISunbeamsGenerator", "Generator", [CENTER, color("inputColor", (1, 0.5, 0)), num("inputSunRadius", 40, 0, 800, atype="Distance"),
                                       num("inputMaxStriationRadius", 2.58, 0, 10), num("inputStriationStrength", 0.5, 0, 3),
                                       num("inputStriationContrast", 1.375, 0, 5), num("inputTime", 0, 0, 1)], ios=9)
f("CITextImageGenerator", "Generator", [string("inputText", ""), string("inputFontName", "HelveticaNeue"), num("inputFontSize", 12, 0, 128, 9, 128),
                                        num("inputScaleFactor", 1, 0, 50, 1, 4), num("inputPadding", 0, 0, 200, 0, 100)], ios=11)

# -- geometry --
f("CIAffineTransform", "GeometryAdjustment", [I, xform()], ios=5, builtin=False)
f("CIBicubicScaleTransform", "GeometryAdjustment", [I, num("inputScale", 1, 0, 50, 0.05, 1.5), num("inputAspectRatio", 1, 0, 50, 0.05, 1.5),
                                                    num("inputB", 0, 0, 1, prop="parameterB"), num("inputC", 0.75, 0, 1, prop="parameterC")], ios=12)
f("CICrop", "GeometryAdjustment", [I, rect("inputRectangle", (-8.98846567431158e307, -8.98846567431158e307, 1.7976931348623157e308, 1.7976931348623157e308))],
  ios=5, builtin=False)
f("CIEdgePreserveUpsampleFilter", "GeometryAdjustment", [I, img("inputSmallImage"), num("inputSpatialSigma", 3, 0, 5),
                                                         num("inputLumaSigma", 0.15, 0, 1)], ios=10, factory="edgePreserveUpsampleFilter",
  swift="edgePreserveUpsample", proto="CIEdgePreserveUpsample")
FOUR = [point("inputTopLeft", (118, 484)), point("inputTopRight", (646, 507)), point("inputBottomRight", (548, 140)), point("inputBottomLeft", (155, 153))]
f("CIKeystoneCorrectionCombined", "GeometryAdjustment", [I, *FOUR, num("inputFocalLength", 28, 0, 1000, 0, 100)], ios=13,
  base="CIFourCoordinateGeometryFilter")
f("CIKeystoneCorrectionHorizontal", "GeometryAdjustment", [I, *FOUR, num("inputFocalLength", 28, 0, 1000, 0, 100)], ios=13,
  base="CIFourCoordinateGeometryFilter")
f("CIKeystoneCorrectionVertical", "GeometryAdjustment", [I, *FOUR, num("inputFocalLength", 28, 0, 1000, 0, 100)], ios=13,
  base="CIFourCoordinateGeometryFilter")
f("CILanczosScaleTransform", "GeometryAdjustment", [I, num("inputScale", 1, 0, 50, 0.05, 1.5), num("inputAspectRatio", 1, 0, 50, 0.05, 1.5)], ios=6)
f("CIMaximumScaleTransform", "GeometryAdjustment", [I, num("inputScale", 1, 0, 50, 0.05, 1.5), num("inputAspectRatio", 1, 0, 50, 0.05, 1.5)], ios=18)
f("CIPerspectiveCorrection", "GeometryAdjustment", [I, *FOUR, boolean("inputCrop", True)], ios=8, base="CIFourCoordinateGeometryFilter")
f("CIPerspectiveRotate", "GeometryAdjustment", [I, num("inputFocalLength", 28, 0, 1000, 0, 100), num("inputPitch", 0, -PI / 2, PI / 2, atype="Angle"),
                                                num("inputYaw", 0, -PI / 2, PI / 2, atype="Angle"), num("inputRoll", 0, -PI, PI, atype="Angle")], ios=13)
f("CIPerspectiveTransform", "GeometryAdjustment", [I, *FOUR], ios=6, base="CIFourCoordinateGeometryFilter")
f("CIPerspectiveTransformWithExtent", "GeometryAdjustment", [I, rect("inputExtent", (0, 0, 300, 300)), *FOUR], ios=6,
  base="CIFourCoordinateGeometryFilter")
f("CIStraightenFilter", "GeometryAdjustment", [I, ANGLE0], ios=5, factory="straightenFilter", swift="straighten", proto="CIStraighten")

# -- gradients --
f("CIGaussianGradient", "Gradient", [CENTER, color("inputColor0", (1, 1, 1)), color("inputColor1", (0, 0, 0, 0)),
                                     num("inputRadius", 300, 0, 2000, 0, 800, "Distance")], ios=5)
f("CIHueSaturationValueGradient", "Gradient", [num("inputValue", 1, 0, 1), num("inputRadius", 300, 0, 2000, 0, 800, "Distance"),
                                               num("inputSoftness", 1, 0, 10), num("inputDither", 1, 0, 5), colorspace(default="sRGB")], ios=10)
f("CILinearGradient", "Gradient", [point("inputPoint0", (0, 0)), point("inputPoint1", (200, 200)), color("inputColor0", (1, 1, 1)),
                                   color("inputColor1", (0, 0, 0))], ios=5)
f("CIRadialGradient", "Gradient", [CENTER, num("inputRadius0", 5, 0, 800, atype="Distance"), num("inputRadius1", 100, 0, 800, atype="Distance"),
                                   color("inputColor0", (1, 1, 1)), color("inputColor1", (0, 0, 0))], ios=5)
f("CISmoothLinearGradient", "Gradient", [point("inputPoint0", (0, 0)), point("inputPoint1", (200, 200)), color("inputColor0", (1, 1, 1)),
                                         color("inputColor1", (0, 0, 0))], ios=6)

# -- halftone --
SHARP = num("inputSharpness", 0.7, 0, 1)
f("CICircularScreen", "HalftoneEffect", [I, CENTER, num("inputWidth", 6, 1, 50, 2, 50, "Distance"), SHARP], ios=6)
f("CICMYKHalftone", "HalftoneEffect", [I, CENTER, num("inputWidth", 6, -2, 100, 2, 100, "Distance"), ANGLE0, SHARP,
                                       num("inputGCR", 1, 0, 1, prop="grayComponentReplacement"), num("inputUCR", 0.5, 0, 1, prop="underColorRemoval")],
  ios=6, factory="CMYKHalftone", swift="cmykHalftone")
f("CIDotScreen", "HalftoneEffect", [I, CENTER, ANGLE0, num("inputWidth", 6, 1, 50, 2, 50, "Distance"), SHARP], ios=6)
f("CIHatchedScreen", "HalftoneEffect", [I, CENTER, ANGLE0, num("inputWidth", 6, 1, 50, 2, 50, "Distance"), SHARP], ios=6)
f("CILineScreen", "HalftoneEffect", [I, CENTER, ANGLE0, num("inputWidth", 6, 1, 50, 2, 50, "Distance"), SHARP], ios=6)

# -- reduction --
EXT = rect("inputExtent", (0, 0, 640, 80))
for n, ios in (("CIAreaAverage", 9), ("CIAreaMaximum", 9), ("CIAreaMaximumAlpha", 9), ("CIAreaMinimum", 9), ("CIAreaMinimumAlpha", 9),
               ("CIAreaMinMax", 12), ("CIAreaMinMaxRed", 11), ("CIColumnAverage", 9), ("CIRowAverage", 9), ("CIAreaBoundsRed", 18),
               ("CIAreaAverageMaximumRed", 26)):
    f(n, "Reduction", [I, EXT], ios=ios, proto=n, base="CIAreaReductionFilter")
f("CIAreaHistogram", "Reduction", [I, EXT, num("inputScale", 1, 0, 100, 0, 1), num("inputCount", 64, 1, 2048, 1, 256, "Count", ptype="NSInteger")],
  ios=8, base="CIAreaReductionFilter")
f("CIAreaAlphaWeightedHistogram", "Reduction", [I, EXT, num("inputScale", 1, 0, 100, 0, 1),
                                                num("inputCount", 64, 1, 2048, 1, 256, "Count", ptype="NSInteger")],
  ios=18, base="CIAreaReductionFilter", proto="CIAreaHistogram")
f("CIAreaLogarithmicHistogram", "Reduction", [I, EXT, num("inputScale", 1, 0, 100, 0, 1), num("inputCount", 64, 1, 2048, 1, 256, "Count", ptype="NSInteger"),
                                              num("inputMinimumStop", -10, -30, 30), num("inputMaximumStop", 4, -30, 30)], ios=16,
  base="CIAreaReductionFilter")
f("CIHistogramDisplayFilter", "Reduction", [I, num("inputHeight", 100, 1, 200), num("inputHighLimit", 1, 0, 1), num("inputLowLimit", 0, 0, 1)],
  ios=8, factory="histogramDisplayFilter", swift="histogramDisplay", proto="CIHistogramDisplay")
f("CIKMeans", "Reduction", [I, EXT, img("inputMeans", prop="inputMeans"), num("inputCount", 8, 0, 128, atype="Count", ptype="NSInteger"),
                            num("inputPasses", 5, 0, 20, atype="Count"), boolean("inputPerceptual", False)], ios=13,
  factory="KMeansFilter", swift="kMeans", base="CIAreaReductionFilter")

# -- sharpen --
f("CISharpenLuminance", "Sharpen", [I, num("inputSharpness", 0.4, 0, 2), num("inputRadius", 1.69, 0, 20, atype="Distance")], ios=6)
f("CIUnsharpMask", "Sharpen", [I, num("inputRadius", 2.5, 0, 100, atype="Distance"), num("inputIntensity", 0.5, 0, 10)], ios=6)

# -- stylize --
for n, ios in (("CIBlendWithAlphaMask", 7), ("CIBlendWithBlueMask", 11), ("CIBlendWithMask", 6), ("CIBlendWithRedMask", 11)):
    f(n, "Stylize", [I, BG, MASK], ios=ios, proto="CIBlendWithMask")
f("CIBloom", "Stylize", [I, num("inputRadius", 10, 0, 100, atype="Distance"), num("inputIntensity", 0.5, 0, 1)], ios=6)
f("CIComicEffect", "Stylize", [I], ios=9)
CONV = (("CIConvolution3X3", 7, 9), ("CIConvolution5X5", 7, 25), ("CIConvolution7X7", 9, 49), ("CIConvolution9Horizontal", 7, 9),
        ("CIConvolution9Vertical", 7, 9), ("CIConvolutionRGB3X3", 15, 9), ("CIConvolutionRGB5X5", 15, 25), ("CIConvolutionRGB7X7", 15, 49),
        ("CIConvolutionRGB9Horizontal", 15, 9), ("CIConvolutionRGB9Vertical", 15, 9))
for n, ios, k in CONV:
    w = [0.0] * k
    w[k // 2 if "Horizontal" in n or "Vertical" in n else k // 2] = 1.0
    f(n, "Stylize", [I, vec("inputWeights", tuple(w)), num("inputBias", 0, -1, 1)], ios=ios, proto="CIConvolution")
f("CICoreMLModelFilter", "Stylize", [I, obj("inputModel", "MLModel", prop="model"), num("inputHeadIndex", 0, 0, 10, atype="Integer"),
                                     boolean("inputSoftmaxNormalization", False)], ios=12, factory="coreMLModelFilter", swift="coreMLModel",
  proto="CICoreMLModel")
f("CICrystallize", "Stylize", [I, num("inputRadius", 20, 1, 100, atype="Distance"), CENTER], ios=9)
f("CIDepthOfField", "Stylize", [I, point("inputPoint0", (0, 300)), point("inputPoint1", (300, 300)), num("inputSaturation", 1.5, 0, 10, 0, 2),
                                num("inputUnsharpMaskRadius", 2.5, 0, 10, 0, 10, "Distance"), num("inputUnsharpMaskIntensity", 0.5, 0, 10, 0, 10),
                                num("inputRadius", 6, 0, 30, 0, 30, "Distance")], ios=9)
f("CIEdges", "Stylize", [I, num("inputIntensity", 1, 0, 10)], ios=9)
f("CIEdgeWork", "Stylize", [I, num("inputRadius", 3, 0, 20, atype="Distance")], ios=9)
f("CIGaborGradients", "Stylize", [I], ios=12)
f("CIGloom", "Stylize", [I, num("inputRadius", 10, 0, 100, atype="Distance"), num("inputIntensity", 0.5, 0, 1)], ios=6)
f("CIHeightFieldFromMask", "Stylize", [I, num("inputRadius", 10, 0, 300, 0, 300, "Distance")], ios=9)
f("CIHexagonalPixellate", "Stylize", [I, CENTER, num("inputScale", 8, 1, 100, 1, 100, "Distance")], ios=9)
f("CIHighlightShadowAdjust", "Stylize", [I, num("inputRadius", 0, 0, 10), num("inputShadowAmount", 0, -1, 1), num("inputHighlightAmount", 1, 0, 1)], ios=5)
f("CILineOverlay", "Stylize", [I, num("inputNRNoiseLevel", 0.07, 0, 0.1), num("inputNRSharpness", 0.71, 0, 2), num("inputEdgeIntensity", 1, 0, 200),
                               num("inputThreshold", 0.1, 0, 1), num("inputContrast", 50, 0.25, 200)], ios=9)
f("CIMix", "Stylize", [I, BG, num("inputAmount", 1, 0, 1)], ios=13)
f("CIPersonSegmentation", "Stylize", [I, num("inputQualityLevel", 0, 0, 2, atype="Integer", ptype="NSUInteger")], ios=15)
f("CIPixellate", "Stylize", [I, CENTER, num("inputScale", 8, 1, 100, 1, 100, "Distance")], ios=6)
f("CIPointillize", "Stylize", [I, num("inputRadius", 20, 1, 100, atype="Distance"), CENTER], ios=9)
f("CISaliencyMapFilter", "Stylize", [I], ios=13, factory="saliencyMapFilter", swift="saliencyMap", proto="CISaliencyMap")
f("CIShadedMaterial", "Stylize", [I, img("inputShadingImage"), num("inputScale", 10, 0, 200, 0, 200, "Distance")], ios=9)
f("CISpotColor", "Stylize", [I, color("inputCenterColor1", (0.0784, 0.0627, 0.0706)), color("inputReplacementColor1", (0.4392, 0.1922, 0.1961)),
                             num("inputCloseness1", 0.22, 0, 1), num("inputContrast1", 0.98, 0, 1),
                             color("inputCenterColor2", (0.5255, 0.3059, 0.3451)), color("inputReplacementColor2", (0.9137, 0.5608, 0.5059)),
                             num("inputCloseness2", 0.15, 0, 1), num("inputContrast2", 0.98, 0, 1),
                             color("inputCenterColor3", (0.9216, 0.4549, 0.3333)), color("inputReplacementColor3", (0.9098, 0.7529, 0.6078)),
                             num("inputCloseness3", 0.5, 0, 1), num("inputContrast3", 0.99, 0, 1)], ios=9)
f("CISpotLight", "Stylize", [I, vec("inputLightPosition", (400, 600, 150), "Position3"), vec("inputLightPointsAt", (200, 200, 0), "Position3"),
                             num("inputBrightness", 3, 0, 10), num("inputConcentration", 0.1, 0.001, 1.5, 0.001, 1.5), color("inputColor", (1, 1, 1), opaque=True)], ios=5)
f("CICannyEdgeDetector", "Stylize", [I, num("inputGaussianSigma", 1.6, 0, 50, 0, 10), boolean("inputPerceptual", False),
                                     num("inputThresholdHigh", 0.05, 0, 1), num("inputThresholdLow", 0.02, 0, 1),
                                     num("inputHysteresisPasses", 1, 0, 20, atype="Integer", ptype="NSInteger")], ios=17)
f("CISobelGradients", "Stylize", [I], ios=17)
f("CIDistanceGradientFromRedMask", "Stylize", [I, num("inputMaximumDistance", 10, 0, 1000, 0, 100, "Distance")], ios=17)
f("CISignedDistanceGradientFromRedMask", "Stylize", [I, num("inputMaximumDistance", 10, 0, 1000, 0, 100, "Distance")], ios=17)

# -- tile --
WIDTH100 = num("inputWidth", 100, 0, 1000, 0, 200, "Distance")
ACUTE = num("inputAcuteAngle", PI / 2, -PI, PI, atype="Angle")
f("CIAffineClamp", "TileEffect", [I, xform()], ios=6)
f("CIAffineTile", "TileEffect", [I, xform()], ios=6)
f("CIEightfoldReflectedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CIFourfoldReflectedTile", "TileEffect", [I, CENTER, ANGLE0, ACUTE, WIDTH100], ios=6)
f("CIFourfoldRotatedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CIFourfoldTranslatedTile", "TileEffect", [I, CENTER, ANGLE0, ACUTE, WIDTH100], ios=6)
f("CIGlideReflectedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CIKaleidoscope", "TileEffect", [I, num("inputCount", 6, 1, 64, 1, 64, "Scalar", ptype="NSInteger"), CENTER, ANGLE0], ios=9)
f("CIOpTile", "TileEffect", [I, CENTER, num("inputScale", 2.8, 0, 10), ANGLE0, num("inputWidth", 65, 0, 1000, 0, 1000, "Distance")], ios=9)
f("CIParallelogramTile", "TileEffect", [I, CENTER, ANGLE0, ACUTE, WIDTH100], ios=6)
f("CIPerspectiveTile", "TileEffect", [I, *FOUR], ios=6, base="CIFourCoordinateGeometryFilter")
f("CISixfoldReflectedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CISixfoldRotatedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CITriangleKaleidoscope", "TileEffect", [I, point("inputPoint", (150, 150)), num("inputSize", 700, 0, 1000, atype="Distance"),
                                           num("inputRotation", 5.924, -2 * PI, 2 * PI, atype="Angle"), num("inputDecay", 0.85, 0, 1)], ios=9)
f("CITriangleTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)
f("CITwelvefoldReflectedTile", "TileEffect", [I, CENTER, ANGLE0, WIDTH100], ios=6)

# -- transitions --
EXT300 = rect("inputExtent", (0, 0, 300, 300))
f("CIAccordionFoldTransition", "Transition", [I, TARGET, num("inputBottomHeight", 0, 0, 100000, 0, 100, "Distance"),
                                              num("inputNumberOfFolds", 3, 1, 50, 1, 10), num("inputFoldShadowAmount", 0.1, 0, 1), TIME],
  ios=8, base="CITransitionFilter")
f("CIBarsSwipeTransition", "Transition", [I, TARGET, num("inputAngle", PI, -PI, PI, atype="Angle"), num("inputWidth", 30, 2, 300, atype="Distance"),
                                          num("inputBarOffset", 10, 1, 100), TIME], ios=6, base="CITransitionFilter")
f("CICopyMachineTransition", "Transition", [I, TARGET, EXT300, color("inputColor", (0.6, 1, 1), opaque=True), TIME,
                                            ANGLE0, num("inputWidth", 200, 0.1, 1000, 0.1, 500, "Distance"), num("inputOpacity", 1.3, 0, 3)],
  ios=6, base="CITransitionFilter")
f("CIDisintegrateWithMaskTransition", "Transition", [I, TARGET, MASK, TIME, num("inputShadowRadius", 8, 0, 50, atype="Distance"),
                                                     num("inputShadowDensity", 0.65, 0, 1), vec("inputShadowOffset", (0, -10), "Offset")],
  ios=6, base="CITransitionFilter")
f("CIDissolveTransition", "Transition", [I, TARGET, TIME], ios=6, base="CITransitionFilter")
f("CIFlashTransition", "Transition", [I, TARGET, CENTER, EXT300, color("inputColor", (1, 0.8, 0.6), opaque=True), TIME,
                                      num("inputMaxStriationRadius", 2.58, 0, 10), num("inputStriationStrength", 0.5, 0, 3),
                                      num("inputStriationContrast", 1.375, 0, 5), num("inputFadeThreshold", 0.85, 0, 1)], ios=6,
  base="CITransitionFilter")
f("CIModTransition", "Transition", [I, TARGET, CENTER, TIME, num("inputAngle", 2, -PI, PI, atype="Angle"), num("inputRadius", 150, 1, 1000, 1, 500, "Distance"),
                                    num("inputCompression", 300, 1, 1000, 1, 800, "Distance")], ios=6, base="CITransitionFilter")
f("CIPageCurlTransition", "Transition", [I, TARGET, img("inputBacksideImage"), img("inputShadingImage"), EXT300, TIME, ANGLE0,
                                         num("inputRadius", 100, 0.01, 1000, 0.01, 400, "Distance")], ios=9, base="CITransitionFilter")
f("CIPageCurlWithShadowTransition", "Transition", [I, TARGET, img("inputBacksideImage"), rect("inputExtent", (0, 0, 0, 0)), TIME, ANGLE0,
                                                   num("inputRadius", 100, 0.01, 1000, 0.01, 400, "Distance"), num("inputShadowSize", 0.5, 0, 1),
                                                   num("inputShadowAmount", 0.7, 0, 1), rect("inputShadowExtent", (0, 0, 0, 0))],
  ios=9, base="CITransitionFilter")
f("CIRippleTransition", "Transition", [I, TARGET, img("inputShadingImage"), CENTER, EXT300, TIME, num("inputWidth", 100, 1, 1000, 10, 300, "Distance"),
                                       num("inputScale", 50, -50, 50)], ios=6, base="CITransitionFilter")
f("CISwipeTransition", "Transition", [I, TARGET, EXT300, color("inputColor", (1, 1, 1), opaque=True), TIME, ANGLE0,
                                      num("inputWidth", 300, 0.1, 1000, 0.1, 800, "Distance"), num("inputOpacity", 0, 0, 1)], ios=6,
  base="CITransitionFilter")

SHARED = {  # protocols shared by several filters / bases: their properties
    "CICompositeOperation": [img(), img("inputBackgroundImage")],
    "CIPhotoEffect": [img(), boolean("inputExtrapolate", False)],
    "CIAreaReductionFilter": [img(), EXT],
    "CIBlendWithMask": [img(), img("inputBackgroundImage"), MASK],
    "CIConvolution": [img(), vec("inputWeights", (0,)), num("inputBias", 0)],
    "CIFourCoordinateGeometryFilter": [img(), *FOUR],
    "CITransitionFilter": [img(), TARGET, TIME],
}
PROTO_IOS = {"CIPhotoEffect.extrapolate": 15, "CIRoundedRectangleGenerator.smoothness": 26,
             "CIRoundedRectangleStrokeGenerator.smoothness": 26}

CATS = {"Blur": "kCICategoryBlur", "ColorAdjustment": "kCICategoryColorAdjustment", "ColorEffect": "kCICategoryColorEffect",
        "CompositeOperation": "kCICategoryCompositeOperation", "DistortionEffect": "kCICategoryDistortionEffect",
        "Generator": "kCICategoryGenerator", "GeometryAdjustment": "kCICategoryGeometryAdjustment", "Gradient": "kCICategoryGradient",
        "HalftoneEffect": "kCICategoryHalftoneEffect", "Reduction": "kCICategoryReduction", "Sharpen": "kCICategorySharpen",
        "Stylize": "kCICategoryStylize", "TileEffect": "kCICategoryTileEffect", "Transition": "kCICategoryTransition"}
HDR = {"Blur", "ColorAdjustment", "CompositeOperation", "GeometryAdjustment", "Sharpen", "TileEffect", "DistortionEffect", "Transition"}


def display_name(n):
    s = n[2:]
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", s)
    s = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", s)
    return s.replace("X Ray", "X-Ray").replace("Q R ", "QR ").replace("P D F417", "PDF417")


def objc_type(t):
    return t


def emit_header():
    out = ['#pragma once',
           '/* GENERATED by isim/frameworks/CoreImage/gen_filters.py: the typed filter protocols and factories of iOS\'s',
           ' * CIFilterBuiltins.h (Swift: import CoreImage.CIFilterBuiltins; let f = CIFilter.gaussianBlur(); f.radius = 4). */',
           '#import <CoreImage/CIFilter.h>', '#import <CoreImage/CIColor.h>', '#import <CoreImage/CIVector.h>',
           '#import <CoreImage/CIBarcodeDescriptor.h>', '', 'NS_ASSUME_NONNULL_BEGIN', '@class MLModel;', '',
           '/* Swift: CIFilterProtocol */', '@protocol CIFilter', '@property (readonly, nonatomic, nullable) CIImage *outputImage;', '@optional',
           '+ (nullable NSDictionary<NSString *, id> *)customAttributes;', '@end', '']
    done = set()

    def prop_line(i, avail=None):
        t = i.ptype
        av = f" API_AVAILABLE(ios({avail}.0))" if avail else ""
        if t.endswith("*"):
            mem = "copy" if t in ("NSString *", "NSAttributedString *", "NSData *", "NSArray *") else "retain"
            nullable = ", nullable" if t.startswith("CIImage") or i.default is None else ""
            return f"@property (nonatomic, {mem}{nullable}) {t}{i.prop}{av};"
        if t == "CIDynamicRangeOption":
            return f"@property (nonatomic, copy, nullable) CIDynamicRangeOption {i.prop}{av};"
        if t == "CGColorSpaceRef":
            return f"@property (nonatomic, nullable) CGColorSpaceRef {i.prop}{av};"
        return f"@property (nonatomic) {t} {i.prop}{av};"

    for name, props in SHARED.items():
        out.append(f"@protocol {name} <CIFilter>")
        for i in props:
            out.append(prop_line(i, PROTO_IOS.get(f"{name}.{i.prop}")))
        out += ["@end", ""]
        done.add(name)
    for flt in FILTERS:
        if not flt.builtin or flt.proto in done:
            continue
        done.add(flt.proto)
        base = flt.base or "CIFilter"
        have = {i.prop for i in SHARED.get(flt.base, [])}
        out.append(f"@protocol {flt.proto} <{base}>")
        for i in flt.inputs:
            if i.prop not in have:
                out.append(prop_line(i, PROTO_IOS.get(f"{flt.proto}.{i.prop}")))
        out += ["@end", ""]
    out.append("@interface CIFilter (Builtins)")
    for flt in FILTERS:
        if not flt.builtin:
            continue
        av = f" API_AVAILABLE(ios({int(flt.ios)}.0))" if flt.ios >= 13 else ""
        out.append(f"+ (CIFilter<{flt.proto}> *){flt.factory} NS_SWIFT_NAME({flt.swift}()){av};")
    out += ["@end", "", "NS_ASSUME_NONNULL_END", ""]
    return "\n".join(out)


def c_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def c_num(v):
    if v is None:
        return "NAN"
    if v == "identity":
        return "0"
    return repr(float(v))


def emit_spec():
    out = ["/* GENERATED by gen_filters.py: the built-in filter registry (see CIFilter.m) */"]
    for k, flt in enumerate(FILTERS):
        rows = []
        for i in flt.inputs:
            d = i.default
            vals = []
            if isinstance(d, tuple):
                vals = list(d)
            elif isinstance(d, (int, float)) and not isinstance(d, bool):
                vals = [d]
            dstr = "NULL" if not isinstance(d, str) or d == "identity" else c_str(d)
            nv = len(vals)
            vals_c = "{" + ", ".join(c_num(v) for v in (vals or [0])) + "}"
            rows.append(f"    {{ {c_str(i.key)}, {c_str(i.cls)}, {c_str(i.atype)}, {c_str(i.prop)}, {c_str(i.ptype)}, "
                        f"{nv}, (const double[]){vals_c}, {dstr}, {c_num(i.mn)}, {c_num(i.mx)}, {c_num(i.smin)}, {c_num(i.smax)}, "
                        f"{1 if d == 'identity' else 0} }},")
        out.append(f"static const ci_input_spec ci_in_{k}[] = {{")
        out += rows or ["    { NULL }"]
        out.append("};")
    out.append("static const ci_filter_spec ci_filter_specs[] = {")
    for k, flt in enumerate(FILTERS):
        cats = [CATS[flt.cats]]
        if flt.video:
            cats.append("kCICategoryVideo")
        cats.append("kCICategoryStillImage")
        if flt.cats in HDR:
            cats.append("kCICategoryHighDynamicRange")
        if flt.cats in ("CompositeOperation",) or flt.name in ("CIColorMatrix", "CIExposureAdjust"):
            cats.append("kCICategoryInterlaced")
            cats.append("kCICategoryNonSquarePixels")
        cats.append("kCICategoryBuiltIn")
        out.append(f"    {{ {c_str(flt.name)}, {c_str(display_name(flt.name))}, {int(round(flt.ios * 100))}, "
                   f"{c_str(','.join(c[len('kCICategory'):] for c in cats))}, {len(flt.inputs)}, ci_in_{k}, "
                   f"{c_str(flt.factory) if flt.builtin else 'NULL'} }},")
    out.append("};")
    out.append(f"#define CI_FILTER_COUNT {len(FILTERS)}")
    return "\n".join(out) + "\n"


def main():
    names = [f.name for f in FILTERS]
    dup = {n for n in names if names.count(n) > 1}
    assert not dup, dup
    outs = {HEADER: emit_header(), SPEC: emit_spec()}
    check = "--check" in sys.argv
    stale = []
    for path, text in outs.items():
        old = open(path).read() if os.path.exists(path) else None
        if old != text:
            stale.append(path)
            if not check:
                open(path, "w").write(text)
    if check and stale:
        print("stale:", *stale)
        sys.exit(1)
    print(f"{len(FILTERS)} filters")


if __name__ == "__main__":
    main()
