//
//  main.swift
//
//
//  Created by Fabio Mauersberger on 04.08.22.
//

import ImageIO
import ArgumentParser
import Foundation

#if canImport(uniformTypeIdentifier)
import UniformTypeIdentifiers
import AppKit
let kUTTypePNG = UTType.png.identifier as CFString
let kUTTypeJPEG = UTType.jpeg.identifier as CFString
#endif


struct spriteman: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "utility to get/put sprites from/into a sprite map",
        subcommands: [extract.self, combine.self])
    
    struct extract: ParsableCommand {
        
        static var configuration = CommandConfiguration(abstract: "extract single file sprites from a sprite map")
        
        @Argument(help: "the source map file")
        var file: String
        
        @Option(help: "the output directory")
        var outputDirectory: String = "output"
        
        @Option(help: "the tile size")
        var tilesize: Int
        
        @Flag(help: "make the colored background transparent")
        var makeAlpha: Bool = false
        
        @Option(help: "interpolate the images by one/multiple factors")
        var interpolate: [Double] = []
        
        @Option(help: "magnify the images by one/multiple factors")
        var magnify: [Int] = []
        
        @Flag(name: [.long], help: "also magnify the interpolated images")
        var magnifyInterpolated: Bool = false
        
        mutating func run() throws {
            let mapSourceSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil)!
            guard let mapSource = CGImageSourceCreateImageAtIndex(mapSourceSource, 0, nil) else {
                throw ValidationError("Image file contains no images")
            }
            /*
             guard (mapSource.width & tilesize == 0) && (mapSource.height & tilesize == 0) else {
             print(mapSource.width & tilesize, mapSource.height & tilesize)
             throw ValidationError("image size must be divisable by the image size")
             }*/
            //print(mapSource.height, mapSource.width)
            for y in 0...mapSource.height/tilesize-1 {
                for x in 0...mapSource.width/tilesize-1 {
                    let croppedRect = CGRect(x: x*tilesize, y: y*tilesize, width: tilesize, height: tilesize)
                    if let potentialImage = mapSource.cropping(to: croppedRect), !potentialImage.isSingleColor() {
                        guard potentialImage.write(to: URL(fileURLWithPath: outputDirectory, isDirectory: true).appendingPathComponent("\(x+1)x\(y+1)_\(tilesize)x\(tilesize)@1x.png")) else {
                            fatalError("Saving \(x+1)x\(y+1)_\(tilesize)x\(tilesize)@1x.png failed!")
                        }
                        for interpolate in interpolate {
                            let url = URL(fileURLWithPath: outputDirectory, isDirectory: true).appendingPathComponent("\(x+1)x\(y+1)_\(Int(Double(tilesize)*interpolate))x\(Int(Double(tilesize)*interpolate))@1x.png")
                            guard let image = potentialImage.interpolate(for: potentialImage.size*interpolate, with: .high) else { fatalError("Interpolation failed!") }
                            guard image.write(to: url) else { fatalError("Saving \(url) failed!") }
                            if magnifyInterpolated {
                                for magnification in magnify {
                                    let url = URL(fileURLWithPath: outputDirectory, isDirectory: true).appendingPathComponent("\(x+1)x\(y+1)_\(Int(Double(tilesize)*interpolate))x\(Int(Double(tilesize)*interpolate))@\(magnification)x.png")
                                    guard let image = image.interpolate(for: image.size*magnification, with: .none) else { fatalError("Interpolation failed!") }
                                    guard image.write(to: url) else { fatalError("Saving \(url) failed!") }
                                }
                            }
                        }
                        for magnification in magnify {
                            let url = URL(fileURLWithPath: outputDirectory, isDirectory: true).appendingPathComponent("\(x+1)x\(y+1)_\(tilesize)x\(tilesize)@\(magnification)x.png")
                            guard let potentialImage = potentialImage.interpolate(for: potentialImage.size*magnification, with: .none) else { fatalError("Magnificatin failed!") }
                            guard potentialImage.write(to: url) else { fatalError("Saving \(url) failed!") }
                        }
                    }
                }
            }
            
            
        }
        
        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: file) else {
                throw ValidationError("File does not exist!")
            }
            var directory: ObjCBool = false
            if !(FileManager.default.fileExists(atPath: outputDirectory, isDirectory: &directory)) || !directory.boolValue {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: outputDirectory, isDirectory: true), withIntermediateDirectories: true)
            }
        }
    }
    
    struct combine: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "combine several image files into one single map (for now only optimized (but not limited to) one sprite size)")
        
        @Argument(help: "the input directory")
        var inputDirectory: String
        
        mutating func validate() throws {
            var directory: ObjCBool = false
            if !(FileManager.default.fileExists(atPath: inputDirectory, isDirectory: &directory) && directory.boolValue) {
                throw ValidationError("Input directory not existing!")
            }
            if try FileManager.default.contentsOfDirectory(atPath: inputDirectory).isEmpty {
                throw ValidationError("Input directory is empty!")
            }
        }
        
        mutating func run() throws {
            let images = try FileManager.default.contentsOfDirectory(atPath: inputDirectory).sorted().compactMap({ file -> CGImage? in
                let url = URL(fileURLWithPath: inputDirectory, isDirectory: true).appendingPathComponent(file)
                guard let dataProvider = CGDataProvider(url: url as CFURL) else { return nil }
                return url.pathExtension == "png"
                ? CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
                : url.pathExtension == "jpg" || url.pathExtension == "jpeg"
                ? CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
                : nil
            })
            guard !images.isEmpty else { throw ValidationError("No images found!") }
            let canvas = images.calulateCanvas()!
            let map = images.placing(onto: canvas)!
                    guard map.write(to: URL(fileURLWithPath: inputDirectory, isDirectory: true).deletingLastPathComponent().appendingPathComponent(inputDirectory + ".png")) else {
                        fatalError("Saving image failed!")
                    }
                 
            
        }
    }
    
}
spriteman.main()

extension CGImage {
    
    // Current (pretty fast, at least faster than NSBitmapImageRep.bitmapData) version based off
    // https://stackoverflow.com/questions/71169691/getting-a-cgcontext-from-a-cgimage and
    // https://gist.github.com/figgleforth/b5b193c3379b3f048210
    // (including https://gist.github.com/figgleforth/b5b193c3379b3f048210?permalink_comment_id=4069753#gistcomment-4069753)
    // Thanks for your work, without you it would've taken much longer to learn how one can use Core Graphics to actually do stuff like this.
    public func isSingleColor() -> Bool {
        guard let imageData = self.dataProvider?.data else { return true }
        var bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: CFDataGetLength(imageData))
        CFDataGetBytes(imageData, .init(location: 0, length: CFDataGetLength(imageData)), bytes)
        var lastColor: CGColor? = nil
        for _ in 0..<self.height*self.width {
            let rgba = [nil,nil,nil,nil].map({ _ -> UInt8 in
                let b = bytes.pointee
                bytes = bytes.advanced(by: 1)
                return b
            })
            let color = CGColor(red: CGFloat(rgba[0])/255.0, green: CGFloat(rgba[1])/255.0, blue: CGFloat(rgba[2])/255.0, alpha: CGFloat(rgba[3])/255.0)
            if lastColor != color && lastColor != nil {
                return false
            }
            lastColor = color
        }
        return true
    }
    
    public func interpolate(for size: CGSize, with quality: CGInterpolationQuality) -> CGImage? {
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(size.width)*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = quality
        context?.draw(self, in: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
        let newImage = context?.makeImage()
        return newImage
    }
    
    public var size: CGSize {
        CGSize(width: width, height: height)
    }
    
    public func write(to url: URL) -> Bool {
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, (url.pathExtension == "png" ? kUTTypePNG : kUTTypeJPEG) as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, self, nil)
        return CGImageDestinationFinalize(destination)
    }
}

extension CGSize {
    public static func *(lhs: CGSize, rhs: Double) -> CGSize {
        CGSize(width: Double(lhs.width)*rhs, height: Double(lhs.height)*rhs)
    }
    
    public static func *(lhs: CGSize, rhs: Int) -> CGSize {
        CGSize(width: Int(lhs.width)*rhs, height: Int(lhs.height)*rhs)
    }
}

extension CGPoint {
    // this is cursed
    public static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        var lhs = lhs
        lhs.x += rhs.x
        lhs.y += rhs.y
        return lhs
    }
}

extension Array where Element == CGImage {
    public func calulateCanvas(with color: CGColor = .clear) -> CGImage? {
        /*let (totalWidth, totalHeight) = self.reduce((0, 0)) { r, image in
            (r.0 + image.width, r.1 + image.height)
        }*/
        let maxWidth = self.max(by: {$0.width > $1.width})!.width
        let maxHeight = self.max(by: {$0.height > $1.height})!.height
        let width = maxWidth*maxWidth
        var height = maxHeight*maxHeight
        while width*(height-maxHeight) >= self.count*maxWidth*maxHeight { // basically... cut away lines if possible
            height -= maxHeight
        }
        print(maxWidth, maxHeight)
        print(width, height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4*maxWidth*maxWidth, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(color)
        context?.fill(CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: width, height: height)))
        return context?.makeImage()
    }
    
    public func placing(onto canvas: CGImage) -> CGImage? {
        let sortedImages = self.sorted(by: {$0.width*$0.height > $1.width*$1.height}) // biggest items first, the rest can fit in between
        let context = CGContext(data: nil, width: canvas.width, height: canvas.height, bitsPerComponent: canvas.bitsPerComponent, bytesPerRow: canvas.bytesPerRow, space: canvas.colorSpace!, bitmapInfo: canvas.bitmapInfo.rawValue)
        var origin = CGPoint(x: 0, y: 0)
        var done = [CGImage]()
        for image in sortedImages {
            if canvas.width-Int(origin.x) - image.width >= 0 && canvas.height-Int(origin.y) - image.height >= 0{
                context?.draw(image, in: CGRect(origin: origin, size: image.size))
                done.append(image)
                origin = origin + CGPoint(x: image.width, y: 0)
                if (sortedImages-done).first(where: {$0.width <= canvas.width-Int(origin.x)}) == nil {
                    origin.x = 0
                    origin.y += CGFloat(image.height)
                }
                if (sortedImages-done).first(where: {$0.height <= canvas.height-Int(origin.y)}) == nil {
                    break
                }
            }
        }
        return done == sortedImages // if all images have been used
        ? context?.makeImage()      // render the generated map
        : nil                       // otherwise return nil
    }
}

extension Array {
    public static func +(lhs: [Element], rhs: Element) -> [Element] {
        var lhs = lhs
        lhs.append(rhs)
        return lhs
    }
}

extension Array where Element: Equatable{
    public static func -(lhs: [Element], rhs: [Element]) -> [Element] {
        var new = [Element]()
        for element in lhs {
            if !rhs.contains(element) {
                new.append(element)
            }
        }
        return new
    }
}

extension Int {
    public func squareRoot() -> Int {
        Int(Double(self).squareRoot())
    }
}
