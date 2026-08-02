// SVG を指定サイズの PNG に描画する（ImageMagick 不要・AppKit のみ）。
// usage: swift render_icon.swift <in.svg> <out.png> <size> [corner-radius] [margin]
import AppKit

let args = CommandLine.arguments
guard args.count >= 4, let size = Int(args[3]) else {
    FileHandle.standardError.write(Data("usage: render_icon.swift in.svg out.png size [radius] [margin]\n".utf8))
    exit(1)
}
let radius = args.count > 4 ? Double(args[4]) ?? 0 : 0
let margin = args.count > 5 ? Double(args[5]) ?? 0 : 0

guard let svg = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("cannot load \(args[1])\n".utf8))
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let content = NSRect(
    x: margin, y: margin,
    width: Double(size) - margin * 2, height: Double(size) - margin * 2)
if radius > 0 {
    NSBezierPath(roundedRect: content, xRadius: radius, yRadius: radius).addClip()
}
svg.draw(in: content, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: args[2]))
