//
//  Created by Kiavash Faisali on 2015-03-17.
//  Copyright (c) 2015 Kiavash Faisali. All rights reserved.
//

import UIKit
import MapKit
import WatchKit

// MARK: - ImageCacheKeys Struct
fileprivate struct ImageCacheKeys {
    static let image = "image"
    static let isDownloading = "isDownloading"
    static let observerMapping = "observerMapping"
}

// MARK: - KFImageCacheManager Class
final public class KFImageCacheManager {
    // MARK: - Properties
    public static let sharedInstance = KFImageCacheManager()
    
    // {"url": {"img": UIImage, "isDownloading": Bool, "observerMapping": {Observer: Int}}}
    fileprivate var imageCache = [String: [String: AnyObject]]()
    
    internal lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        
        return URLSession(configuration: configuration)
    }()
    
    /**
        Sets the fade duration time (in seconds) for images when they are being loaded into their views.
        A value of 0 implies no fade animation.
        The default value is 0.1 seconds.
        
        - returns: An NSTimeInterval value representing time in seconds.
    */
    public var fadeAnimationDuration = 0.1 as TimeInterval
    
    /**
        Sets the maximum time (in seconds) that the disk cache will use to maintain a cached response.
        The default value is 60 * 60 * 24 * 21 seconds (3 week).
        
        - returns: An unsigned integer value representing time in seconds.
    */
    public var diskCacheMaxAge = 60 * 60 * 24 * 21 as UInt {
        willSet {
            if newValue == 0 {
                URLCache.shared.removeAllCachedResponses()
            }
        }
    }
    
    /**
        Sets the maximum time (in seconds) that the request should take before timing out.
        The default value is 60 seconds.
        
        - returns: An NSTimeInterval value representing time in seconds.
    */
    public var timeoutIntervalForRequest = 60.0 as TimeInterval {
        willSet {
            let configuration = self.session.configuration
            configuration.timeoutIntervalForRequest = newValue
            self.session = URLSession(configuration: configuration)
        }
    }
    
    /**
        Sets the cache policy which the default requests and underlying session configuration use to determine caching behaviour.
        The default value is `returnCacheDataElseLoad`.
        
        - returns: An NSURLRequestCachePolicy value representing the cache policy.
    */
    public var requestCachePolicy = NSURLRequest.CachePolicy.returnCacheDataElseLoad {
        willSet {
            let configuration = self.session.configuration
            configuration.requestCachePolicy = newValue
            self.session = URLSession(configuration: configuration)
        }
    }
    
    fileprivate init() {
        // Initialize the disk cache capacity to 250 MB.
        let diskURLCache = URLCache(memoryCapacity: 0, diskCapacity: 250 * 1024 * 1024, diskPath: nil)
        URLCache.shared = diskURLCache
        
//        NotificationCenter.default.addObserver(forName: .UIApplicationDidReceiveMemoryWarning, object: nil, queue: .main) {
//            _ in
//            
//            self.imageCache.removeAll(keepingCapacity: false)
//        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Image Cache Subscripting
    internal subscript (key: String) -> UIImage? {
        get {
            return imageCacheEntryForKey(key)[ImageCacheKeys.image] as? UIImage
        }
        set {
            if let image = newValue {
                var imageCacheEntry = imageCacheEntryForKey(key)
                imageCacheEntry[ImageCacheKeys.image] = image
                setImageCacheEntry(imageCacheEntry, forKey: key)
                
                if let observerMapping = imageCacheEntry[ImageCacheKeys.observerMapping] as? [NSObject: Int] {
                    for (observer, initialIndexIdentifier) in observerMapping {
                        switch observer {
                        case let interfaceImage as WKInterfaceImage:
                            loadObserver(interfaceImage, image: image, key: key)
                        default:
                            break
                        }
                    }

                    removeImageCacheObserversForKey(key)
                }
            }
        }
    }
    
    // MARK: - Image Cache Methods
    internal func imageCacheEntryForKey(_ key: String) -> [String: AnyObject] {
        if let imageCacheEntry = self.imageCache[key] {
            return imageCacheEntry
        }
        else {
            let imageCacheEntry: [String: AnyObject] = [ImageCacheKeys.isDownloading: false as AnyObject, ImageCacheKeys.observerMapping: [NSObject: Int]() as AnyObject]
            self.imageCache[key] = imageCacheEntry
            
            return imageCacheEntry
        }
    }
    
    internal func setImageCacheEntry(_ imageCacheEntry: [String: AnyObject], forKey key: String) {
        self.imageCache[key] = imageCacheEntry
    }
    
    internal func isDownloadingFromURL(_ urlString: String) -> Bool {
        let isDownloading = imageCacheEntryForKey(urlString)[ImageCacheKeys.isDownloading] as? Bool
        
        return isDownloading ?? false
    }
    
    internal func setIsDownloadingFromURL(_ isDownloading: Bool, forURLString urlString: String) {
        var imageCacheEntry = imageCacheEntryForKey(urlString)
        imageCacheEntry[ImageCacheKeys.isDownloading] = isDownloading as AnyObject?
        setImageCacheEntry(imageCacheEntry, forKey: urlString)
    }
    
    internal func addImageCacheObserver(_ observer: NSObject, withInitialIndexIdentifier initialIndexIdentifier: Int, forKey key: String) {
        var imageCacheEntry = imageCacheEntryForKey(key)
        if var observerMapping = imageCacheEntry[ImageCacheKeys.observerMapping] as? [NSObject: Int] {
            observerMapping[observer] = initialIndexIdentifier
            imageCacheEntry[ImageCacheKeys.observerMapping] = observerMapping as AnyObject?
            setImageCacheEntry(imageCacheEntry, forKey: key)
        }
    }
    
    internal func removeImageCacheObserversForKey(_ key: String) {
        var imageCacheEntry = imageCacheEntryForKey(key)
        if var observerMapping = imageCacheEntry[ImageCacheKeys.observerMapping] as? [NSObject: Int] {
            observerMapping.removeAll(keepingCapacity: false)
            imageCacheEntry[ImageCacheKeys.observerMapping] = observerMapping as AnyObject?
            setImageCacheEntry(imageCacheEntry, forKey: key)
        }
    }
    
    internal func loadObserver(_ interfaceImage: WKInterfaceImage, image: UIImage, key: String) {
        DispatchQueue.main.async {

            interfaceImage.setImageData(image.pngData())

            interfaceImage.completionHolder.completion?(true, nil)
        }
    }
}
