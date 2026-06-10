// V2 of the 3-lights icon. Unlike v1 (which painted a dark rounded
// square *background* with the lights floating on top), this version
// makes the dark housing a discrete object in the middle of a clean
// white canvas — i.e. the icon actually looks like a traffic light,
// not three discs on a dark plate.
//
// Two orientations:
//   swift generate-icon-3lights-v2.swift <out.png> vertical
//   swift generate-icon-3lights-v2.swift <out.png> horizontal
//
// Default is vertical.

import AppKit
import CoreGraphics

let args = CommandLine.arguments
let outputPath = args.count > 1 ? args[1] : "icon-3lights-1024.png"
let orientation = (args.count > 2 ? args[2] : "vertical").lowercased()

let size = 1024
let pixels = CGSize(width: size, height: size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create context") }

// 1. White rounded-square canvas. macOS masks the corners to the
//    standard app-icon shape; we just need the artwork to be a
//    rounded square of the right size inside that mask.
let cornerRadius = CGFloat(size) * 0.225
let canvasRect = CGRect(origin: .zero, size: pixels)
let canvasPath = CGPath(roundedRect: canvasRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(canvasPath)
ctx.clip()

// Fill the canvas with white. A very faint top-to-bottom gradient
// (pure white → 98% white) gives the icon a touch of depth without
// being tinted.
let bgColors = [
    CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
    CGColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
] as CFArray
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end:   CGPoint(x: 0, y: 0),
                       options: [])

// 2. The traffic-light housing. Dark rounded-rectangle that occupies
//    the centre of the canvas. Vertical: tall pill. Horizontal: wide
//    pill. Both use the same stroke-less flat fill, with a subtle
//    vertical gradient to suggest a metal/plastic surface.
let housingCornerRadius: CGFloat
let housingRect: CGRect
if orientation == "horizontal" {
    housingRect = CGRect(
        x: CGFloat(size) * 0.10,
        y: CGFloat(size) * 0.27,
        width:  CGFloat(size) * 0.80,
        height: CGFloat(size) * 0.46
    )
    housingCornerRadius = housingRect.height / 2
} else {
    // default: vertical
    housingRect = CGRect(
        x: CGFloat(size) * 0.27,
        y: CGFloat(size) * 0.08,
        width:  CGFloat(size) * 0.46,
        height: CGFloat(size) * 0.84
    )
    housingCornerRadius = housingRect.width / 2
}

let housingPath = CGPath(roundedRect: housingRect,
                         cornerWidth: housingCornerRadius,
                         cornerHeight: housingCornerRadius,
                         transform: nil)
ctx.addPath(housingPath)
ctx.clip()

let housingColors = [
    CGColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 1.0),
    CGColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0),
] as CFArray
let housingGradient = CGGradient(colorsSpace: colorSpace, colors: housingColors, locations: [0, 1])!
ctx.drawLinearGradient(housingGradient,
                       start: CGPoint(x: 0, y: housingRect.maxY),
                       end:   CGPoint(x: 0, y: housingRect.minY),
                       options: [])

// 3. Three lights. Each is a soft disc with a radial gradient
//    (bright top-left → deep rim) and a tiny white specular spot.
let lightRadius = CGFloat(size) * 0.085

// Inset the lights a bit from the housing edge so they don't bleed
// into the rounded corner. We compute centres along the long axis of
// the housing, evenly spaced.
let lightInset: CGFloat = lightRadius * 1.55  // distance from housing edge to light centre
let lightCentresY: [CGFloat]
let lightCentresX: [CGFloat]

if orientation == "horizontal" {
    let cy = housingRect.midY
    let x0 = housingRect.minX + lightInset
    let x1 = housingRect.midX
    let x2 = housingRect.maxX - lightInset
    lightCentresX = [x0, x1, x2]
    lightCentresY = [cy, cy, cy]
} else {
    let cx = housingRect.midX
    let y0 = housingRect.maxY - lightInset  // top of housing → first light
    let y1 = housingRect.midY
    let y2 = housingRect.minY + lightInset
    lightCentresX = [cx, cx, cx]
    lightCentresY = [y0, y1, y2]
}

struct LightSpec {
    let center: CGPoint
    let topColor: CGColor
    let midColor: CGColor
    let rimColor: CGColor
}

let lights: [LightSpec] = [
    // Red
    LightSpec(
        center: CGPoint(x: lightCentresX[0], y: lightCentresY[0]),
        topColor: CGColor(red: 1.00, green: 0.78, blue: 0.74, alpha: 1.0),
        midColor: CGColor(red: 0.98, green: 0.36, blue: 0.32, alpha: 1.0),
        rimColor: CGColor(red: 0.45, green: 0.08, blue: 0.06, alpha: 1.0)
    ),
    // Yellow
    LightSpec(
        center: CGPoint(x: lightCentresX[1], y: lightCentresY[1]),
        topColor: CGColor(red: 1.00, green: 0.95, blue: 0.70, alpha: 1.0),
        midColor: CGColor(red: 0.98, green: 0.78, blue: 0.22, alpha: 1.0),
        rimColor: CGColor(red: 0.50, green: 0.36, blue: 0.04, alpha: 1.0)
    ),
    // Green
    LightSpec(
        center: CGPoint(x: lightCentresX[2], y: lightCentresY[2]),
        topColor: CGColor(red: 0.75, green: 1.00, blue: 0.78, alpha: 1.0),
        midColor: CGColor(red: 0.32, green: 0.88, blue: 0.42, alpha: 1.0),
        rimColor: CGColor(red: 0.08, green: 0.42, blue: 0.16, alpha: 1.0)
    ),
]

for spec in lights {
    let highlight = CGPoint(
        x: spec.center.x - lightRadius * 0.20,
        y: spec.center.y + lightRadius * 0.20
    )
    let bodyColors = [spec.topColor, spec.midColor, spec.rimColor] as CFArray
    let bodyGradient = CGGradient(colorsSpace: colorSpace, colors: bodyColors, locations: [0.0, 0.55, 1.0])!
    ctx.drawRadialGradient(bodyGradient,
                           startCenter: highlight, startRadius: 0,
                           endCenter:   spec.center, endRadius: lightRadius,
                           options: [])

    // Specular highlight (small soft white blob, top-left).
    let specCenter = CGPoint(
        x: spec.center.x - lightRadius * 0.30,
        y: spec.center.y + lightRadius * 0.42
    )
    let specColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0),
    ] as CFArray
    let specGradient = CGGradient(colorsSpace: colorSpace, colors: specColors, locations: [0, 1])!
    ctx.drawRadialGradient(specGradient,
                           startCenter: specCenter, startRadius: 0,
                           endCenter:   specCenter, endRadius: lightRadius * 0.42,
                           options: [])
}

guard let image = ctx.makeImage() else { fatalError("Could not make image") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) [\(orientation)] (\(data.count) bytes)")
