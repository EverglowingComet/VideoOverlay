//
//  OverlayRenderer.swift
//  VideoOverlay
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//
//

import Foundation
import MetalKit
import AVKit

final class OverlayRenderer {
    
    var strength = 0.5
    
    var background : UIImage
    
    let back_reader: VideoSeqReader
    let front_reader: VideoSeqReader
    
    var backLayout : DBVideoLayout
    var frontLayout : DBVideoLayout
    
    var outputSize : CGSize
    
    let back_duration : CMTime
    let front_duration : CMTime
    
    var presentationTime : CMTime = CMTime.zero
    
    var frameCount = 0
    
    var transtionSecondes : Double = 5
    
    
    var inputTime: CFTimeInterval?
    
    var pixelBuffer: CVPixelBuffer?
    
    var textureCache: CVMetalTextureCache?
    var commandQueue: MTLCommandQueue
    var computePipelineState: MTLComputePipelineState
    
    init(asset: AVAsset, asset1: AVAsset, layout1: DBVideoLayout, layout2 : DBVideoLayout, videoSize: CGSize) {
        back_reader = VideoSeqReader(asset: asset)
        front_reader = VideoSeqReader(asset: asset1)
        
        back_duration = asset.duration
        front_duration = asset1.duration
        
        backLayout = layout1
        frontLayout = layout2
        
        outputSize = videoSize
        
        // Get the default metal device.
        let metalDevice = MTLCreateSystemDefaultDevice()!
        
        // Create a command queue.
        commandQueue = metalDevice.makeCommandQueue()!
        
        // Create the metal library containing the shaders
        let bundle = Bundle.main
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! metalDevice.makeLibrary(filepath: url!.path)
        
        // Create a function with a specific name.
        let function = library.makeFunction(name: "produce_frame")!
        
        // Create a compute pipeline with the above function.
        computePipelineState = try! metalDevice.makeComputePipelineState(function: function)
        
        // Initialize the cache to convert the pixel buffer into a Metal texture.
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache.")
        }
        else {
            textureCache = textCache
        }
        
        guard let url1 = Bundle.main.url(forResource: "background", withExtension: "png") else {
            print("Impossible to find the background.")
            background = UIImage(named: "background")!
            return
        }
        
        background = UIImage(contentsOfFile: url1.path)!
        
    }
    
    public func initFunction() {
        
    }
    
    func next() -> (CVPixelBuffer, CMTime)? {
        let duration = min(back_duration.seconds, front_duration.seconds)
        
        if let frame = back_reader.next(), let frame1 = front_reader.next() {
            
            let frameRate = back_reader.nominalFrameRate
            presentationTime = CMTimeMake(value: Int64(frameCount * 600), timescale: Int32(600 * frameRate))
            //let image = frame.filterWith(filters: filters)
            let progress = transtionSecondes / duration
            
            if let targetTexture = render(pixelBuffer: frame, pixelBuffer2: frame1, progress: Float(progress)) {
                var outPixelbuffer: CVPixelBuffer?
                if let datas = targetTexture.buffer?.contents() {
                    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, targetTexture.width,
                                                 targetTexture.height, kCVPixelFormatType_64RGBAHalf, datas,
                                                 targetTexture.bufferBytesPerRow, nil, nil, nil, &outPixelbuffer);
                    if outPixelbuffer != nil {
                        frameCount += 1
                        
                        return (outPixelbuffer!, presentationTime)
                    }
                    
                }
            }
            
            
            frameCount += 1
            
            return (frame, presentationTime)
        }
        
        
        return nil
        
    }
    
    public func render(pixelBuffer: CVPixelBuffer, pixelBuffer2: CVPixelBuffer, progress: Float) -> MTLTexture? {
        // here the metal code
        // Check if the pixel buffer exists
        
        // Get width and height for the pixel buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create metal texture")
            return nil
        }
        
        
        // Get width and height for the pixel buffer
        let width1 = CVPixelBufferGetWidth(pixelBuffer2)
        let height1 = CVPixelBufferGetHeight(pixelBuffer2)
        
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut1: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer2, nil, .bgra8Unorm, width1, height1, 0, &cvTextureOut1)
        guard let cvTexture1 = cvTextureOut1, let inputTexture1 = CVMetalTextureGetTexture(cvTexture1) else {
            print("Failed to create metal texture")
            return nil
        }
        
        /*var pixelBuffer_output: CVPixelBuffer?
        
        let attrs_output = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue]
        
        var status_output = CVPixelBufferCreate(nil, Int(background.size.width), Int(background.size.height),
                                         kCVPixelFormatType_32BGRA, attrs_output as CFDictionary,
                                         &pixelBuffer_output)
        assert(status_output == noErr)
        
        let coreImage_output = CIImage(image: background)!
        let context_output = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)
        context_output.render(coreImage_output, to: pixelBuffer_output!)
        
        var textureWrapper_output: CVMetalTexture?
        
        let wi = CVPixelBufferGetWidth(pixelBuffer_output!)
        let he = CVPixelBufferGetHeight(pixelBuffer_output!)
        
        status_output = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           self.textureCache!, pixelBuffer_output!, nil, .bgra8Unorm,
                                                           CVPixelBufferGetWidth(pixelBuffer_output!), CVPixelBufferGetHeight(pixelBuffer_output!), 0, &textureWrapper_output)
        
        guard let cvTexture_output = textureWrapper_output , let inputTexture_output = CVMetalTextureGetTexture(cvTexture_output) else {
            print("Failed to create metal texture sample")
            return nil
        }*/
        
        // Check if Core Animation provided a drawable.
        
        // Create a command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Create a compute command encoder.
        let computeCommandEncoder = commandBuffer!.makeComputeCommandEncoder()
        
        // Set the compute pipeline state for the command encoder.
        computeCommandEncoder!.setComputePipelineState(computePipelineState)
        
        // Set the input and output textures for the compute shader.
        computeCommandEncoder!.setTexture(inputTexture, index: 0)
        computeCommandEncoder!.setTexture(inputTexture, index: 1)
        computeCommandEncoder!.setTexture(inputTexture1, index: 2)
        computeCommandEncoder!.setTexture(inputTexture, index: 3)
        
        
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        
        let threadGroups: MTLSize = {
            MTLSizeMake(Int(width) / threadGroupCount.width, Int(height) / threadGroupCount.height, 1)
        }()
        // Convert the time in a metal buffer.
        var time = Float(progress)
        computeCommandEncoder!.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        
        let backBColor = components(color: backLayout.borderColor);
        var borderColor_r = Float(backBColor![0])
        computeCommandEncoder!.setBytes(&borderColor_r, length: MemoryLayout<Float>.size, index: 1)
        var borderColor_g = Float(backBColor![1])
        computeCommandEncoder!.setBytes(&borderColor_g, length: MemoryLayout<Float>.size, index: 2)
        var borderColor_b = Float(backBColor![2])
        computeCommandEncoder!.setBytes(&borderColor_b, length: MemoryLayout<Float>.size, index: 3)
        var borderColor_a = Float(backLayout.borderColor.cgColor.alpha)
        computeCommandEncoder!.setBytes(&borderColor_a, length: MemoryLayout<Float>.size, index: 4)
        var borderWidth = Float(backLayout.borderWidth)
        computeCommandEncoder!.setBytes(&borderWidth, length: MemoryLayout<Float>.size, index: 5)
        var cornerRadius = Float(backLayout.cornerRadius)
        computeCommandEncoder!.setBytes(&cornerRadius, length: MemoryLayout<Float>.size, index: 6)
        var originX = Float(backLayout.originX)
        computeCommandEncoder!.setBytes(&originX, length: MemoryLayout<Float>.size, index: 7)
        var originY = Float(backLayout.originY)
        computeCommandEncoder!.setBytes(&originY, length: MemoryLayout<Float>.size, index: 8)
        var l_width = Float(backLayout.width)
        computeCommandEncoder!.setBytes(&l_width, length: MemoryLayout<Float>.size, index: 9)
        var l_height = Float(backLayout.height)
        computeCommandEncoder!.setBytes(&l_height, length: MemoryLayout<Float>.size, index: 10)
        
        let frontBColor = components(color: backLayout.borderColor);
        borderColor_r = Float(frontBColor![0])
        computeCommandEncoder!.setBytes(&borderColor_r, length: MemoryLayout<Float>.size, index: 11)
        borderColor_g = Float(frontBColor![1])
        computeCommandEncoder!.setBytes(&borderColor_g, length: MemoryLayout<Float>.size, index: 12)
        borderColor_b = Float(frontBColor![2])
        computeCommandEncoder!.setBytes(&borderColor_b, length: MemoryLayout<Float>.size, index: 13)
        borderColor_a = Float(frontLayout.borderColor.cgColor.alpha)
        computeCommandEncoder!.setBytes(&borderColor_a, length: MemoryLayout<Float>.size, index: 14)
        borderWidth = Float(frontLayout.borderWidth)
        computeCommandEncoder!.setBytes(&borderWidth, length: MemoryLayout<Float>.size, index: 15)
        cornerRadius = Float(frontLayout.cornerRadius)
        computeCommandEncoder!.setBytes(&cornerRadius, length: MemoryLayout<Float>.size, index: 16)
        originX = Float(frontLayout.originX)
        computeCommandEncoder!.setBytes(&originX, length: MemoryLayout<Float>.size, index: 17)
        originY = Float(frontLayout.originY)
        computeCommandEncoder!.setBytes(&originY, length: MemoryLayout<Float>.size, index: 18)
        l_width = Float(frontLayout.width)
        computeCommandEncoder!.setBytes(&l_width, length: MemoryLayout<Float>.size, index: 19)
        l_height = Float(frontLayout.height)
        computeCommandEncoder!.setBytes(&l_height, length: MemoryLayout<Float>.size, index: 20)
        
        
        // Encode a threadgroup's execution of a compute function
        computeCommandEncoder!.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        
        // End the encoding of the command.
        computeCommandEncoder!.endEncoding()
        
        // Register the current drawable for rendering.
        //commandBuffer!.present(drawable)
        
        // Commit the command buffer for execution.
        commandBuffer!.commit()
        commandBuffer!.waitUntilCompleted()
        
        return inputTexture
    }
    
    
    public func getCMSampleBuffer(pixelBuffer : CVPixelBuffer?) -> CMSampleBuffer? {
        
        if pixelBuffer == nil {
            return nil
        }
        
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = CMTime.zero
        info.duration = CMTime.invalid
        info.decodeTimeStamp = CMTime.invalid
        
        
        var formatDesc: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescriptionOut: &formatDesc)
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer!,
                                                 formatDescription: formatDesc!,
                                                 sampleTiming: &info,
                                                 sampleBufferOut: &sampleBuffer);
        
        return sampleBuffer!
    }
    
    func components(color : UIColor) -> [CGFloat]? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if color.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            return [fRed, fGreen, fBlue, fAlpha];
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
}
