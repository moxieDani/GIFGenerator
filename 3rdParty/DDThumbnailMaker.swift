//
//  DDThumbnailMaker.swift
//  DDThumbnailMaker
//
//  Created by Daniel on 2023/02/22.
//

import Foundation
import UIKit
import AVKit

public struct VideoInfo {
    public var videoTracks: [AVAssetTrack]! = nil
    public var resolution: CGSize! = CGSize(width: 0, height: 0)
    public var duration: CMTime! = .zero
    public var frameRate: Float! = 0.0
}

public class DDThumbnailMaker {
    public var avAsset: AVAsset! = nil {
        didSet {
            self.initAsset()
        }
    }
    public var intervalMsec: CMTimeValue! = 1000
    public var intervalFrame: UInt! = 0
    public var targetDuration: CMTimeRange! = nil
    public var targetFrameRate: Float! = 0.0
    public var thumbnailImageSize: CGSize! = CGSize(width: 192, height: 144)

    @available(*, deprecated, message: "Use videoInfo.videoTracks instead")
    public var videoTracks: [AVAssetTrack]! {
        get {
            return self.videoInfo.videoTracks
        }
    }

    @available(*, deprecated, message: "Use videoInfo.frameRate instead")
    public var frameRate: Float! {
        get {
            return self.videoInfo.frameRate
        }
    }

    @available(*, deprecated, message: "Use videoInfo.duration instead")
    public var duration: CMTime! {
        get {
            return self.videoInfo.duration
        }
    }

    public var videoInfo = VideoInfo()
    
    private var generator: AVAssetImageGenerator? = nil

    public init(_ avAsset: AVAsset) {
        self.avAsset = avAsset
        self.initAsset()
    }
    
    public init(_ url:URL) {
        self.avAsset = AVAsset(url: url)
        self.initAsset()
    }
    
    private func initAsset() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await initAssetInternal()
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    private func initAssetInternal() async {
        self.videoInfo.videoTracks = try? await self.avAsset.loadTracks(withMediaType: .video)
        if let videoTracks = self.videoInfo.videoTracks {
            self.videoInfo.frameRate = videoTracks.count > 0 ? try! await videoTracks.first!.load(.nominalFrameRate) : 0.0
            self.videoInfo.duration = try? await self.avAsset.load(.duration)
            
            let size = try! await videoTracks.first!.load(.naturalSize).applying(videoTracks.first!.load(.preferredTransform))
            self.videoInfo.resolution = CGSize(width: abs(size.width), height: abs(size.height))
        }
    }
    
    public func generate(imageHandler:@escaping (CMTime, CGImage?, CMTime, AVAssetImageGenerator.Result, NSError?) ->Void,
                         completion:@escaping () -> Void) {
        Task {
            await generateInternal(imageHandler: imageHandler, completion: completion)
        }
    }
    
    private func generateInternal(imageHandler:@escaping (CMTime, CGImage?, CMTime, AVAssetImageGenerator.Result, NSError?) ->Void,
                                  completion:@escaping () -> Void) async {
        // Get requested asset times
        let times = await getRequestedAssetTimes()

        // AVAssetImageGenerator work
        var count = 0
        let frameCount = times.count
        let generator = getAVAssetImageGenerator()
        generator.generateCGImagesAsynchronously(forTimes: times) { (requestedTime, image, actualTime, result, error) in
            count += 1
            defer {
                if count == frameCount {
                    DispatchQueue.main.async { completion() }
                }
            }
            imageHandler(requestedTime, image, actualTime, result, error as NSError?)
        }
    }
    
    private func getAVAssetImageGenerator() -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: self.avAsset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = self.thumbnailImageSize
        generator.appliesPreferredTrackTransform = true;
        
        return generator
    }
    
    private func getRequestedAssetTimes() async -> [NSValue] {
        // Get information about avAsset
        let durationValue = self.videoInfo.duration.value
        let durationTimescale = self.videoInfo.duration.timescale
        let durationFlags = self.videoInfo.duration.flags
        let durationEpoch = self.videoInfo.duration.epoch
        let frameRate = (self.targetFrameRate == 0 ? self.videoInfo.frameRate : self.targetFrameRate)!
        let numberOfFrames = durationValue * Int64(frameRate) / Int64(durationTimescale)
        
        var times: [NSValue] = []
        for i in 1...numberOfFrames {
            let timeValue = CMTimeValue((durationValue * Int64(i)) / numberOfFrames)
            var shouldAppend = false
            
            if self.intervalFrame > 0 {
                shouldAppend = (UInt(i) % self.intervalFrame == 0)
            } else {
                shouldAppend = (timeValue % self.intervalMsec == 0)
            }

            if self.targetDuration != nil {
                let time = CMTime(seconds: Double(timeValue/Int64(durationTimescale)), preferredTimescale: CMTimeScale(NSEC_PER_MSEC))
                shouldAppend = self.targetDuration.containsTime(time)
            } else {
                shouldAppend = shouldAppend || i==1
            }
            
            if shouldAppend {
                let frameTime = CMTime(value: timeValue, timescale: durationTimescale, flags: durationFlags, epoch: durationEpoch)
                times.append(NSValue(time: frameTime))
            }
        }

        return times
    }
}


