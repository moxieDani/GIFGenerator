//
//  DDThumbnailMaker.swift
//  DDThumbnailMaker
//
//  Created by Daniel on 2023/02/22.
//

import Foundation
import UIKit
import AVKit

public class DDThumbnailMaker {
    public var avAsset: AVAsset! = nil
    public var intervalMsec: CMTimeValue! = 1000
    public var intervalFrame: UInt! = 0
    public var targetDuration: CMTimeRange! = nil
    public var thumbnailImageSize: CGSize! = CGSize(width: 192, height: 144)
    public var videoTracks: [AVAssetTrack]! = nil
    public var frameRate: Int! = 0
    public var duration: CMTime! = .zero
    
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
        self.videoTracks = try? await self.avAsset.loadTracks(withMediaType: .video)
        if let videoTracks = self.videoTracks {
            self.frameRate = videoTracks.count > 0 ? try! await Int(videoTracks.first!.load(.nominalFrameRate)) : 0
            self.duration = try? await self.avAsset.load(.duration)
            
            let size = try! await videoTracks.first!.load(.naturalSize).applying(videoTracks.first!.load(.preferredTransform))
            self.thumbnailImageSize = CGSize(width: abs(size.width), height: abs(size.height))
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
        let durationValue = self.duration.value
        let durationTimescale = self.duration.timescale
        let durationFlags = self.duration.flags
        let durationEpoch = self.duration.epoch
        let numberOfFrames = durationValue * Int64(self.frameRate) / Int64(durationTimescale)
        
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


