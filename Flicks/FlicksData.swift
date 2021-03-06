//
//  FlicksData.swift
//  Flicks
//
//  Created by Hyun Lim on 2/16/16.
//  Copyright © 2016 Lyft. All rights reserved.
//

import Foundation
import AFNetworking

protocol FlicksDataDelegateProtocol: class {
    func dataInFlight() -> Void
    func dataFinishedFlight() -> Void
    func dataErrored() -> Void
}

extension Dictionary {
    mutating func update(other:Dictionary) {
        for (key,value) in other {
            self.updateValue(value, forKey:key)
        }
    }
}


public final class FlicksData {
    // ...
    
    static let CLIENT_ID = "a07e22bc18f5cb106bfe4cc1f83ad8ed"
    static let POPULAR_ENDPOINT = "https://api.themoviedb.org/3/movie/now_playing"
    static let TOP_RATED_ENDPOINT = "https://api.themoviedb.org/3/movie/top_rated"
    
    public var movies:[Movie] = []
    private var cachedMovies:[Movie] = []
    public var dataInFlight:Bool = false
    private var currentPage:Int = 1
    private var searchBeingExecuted:Bool = false
    weak var delegate:FlicksDataDelegateProtocol?
    
    init() {
        self.movies = []
    }
    
    public func refetchPosts(endpoint: String, success: () -> Void, error:((NSError?) -> Void)?) {
        if !self.dataInFlight {
            self.dataInFlight = true
            self.currentPage = 1
            if let delegate = self.delegate {
                delegate.dataInFlight()
            }
            FlicksData.fetchPosts(
                endpoint,
                additionalParams: [:],
                successCallback: {(movies:[Movie]) in
                    self.cachedMovies = movies
                    self.setMovies(nil)
                    success()
                    self.dataInFlight = false
                    if let delegate = self.delegate {
                        delegate.dataFinishedFlight()
                    }
                },
                errorCallback: {(NSError) in
                    // TODO: how to do error handling?
                    self.dataInFlight = false
                    if let delegate = self.delegate {
                        delegate.dataErrored()
                    }
                });
        }
    }
    
    public func setMovies(filter:String?) {
        if let filter = filter {
            let lowerFilter = filter.lowercaseString
            self.searchBeingExecuted = true
            self.movies = self.cachedMovies.filter({ (movie) in movie.title.lowercaseString.containsString(lowerFilter) })
        } else {
            self.movies = self.cachedMovies
            self.searchBeingExecuted = false
        }
    }
    
    public func addMorePosts(endpoint:String, success: () -> Void) {
        if !self.dataInFlight && !self.searchBeingExecuted {
            self.dataInFlight = true
            if let delegate = self.delegate {
                delegate.dataInFlight()
            }
            let params = [
                "page": String(++self.currentPage)
            ]
            FlicksData.fetchPosts(
                endpoint,
                additionalParams: params,
                successCallback: {(movies:[Movie]) in
                    self.cachedMovies = self.cachedMovies + movies
                    self.movies = self.cachedMovies
                    success()
                    self.dataInFlight = false
                    if let delegate = self.delegate {
                        delegate.dataFinishedFlight()
                    }
                },
                errorCallback: {(NSError) in
                    // TODO: how to do error handling?
                    self.dataInFlight = false
                    if let delegate = self.delegate {
                        delegate.dataErrored()
                    }
            });
        }
    }
    
    private static func fetchPosts(endpoint: String, additionalParams:[String:String], successCallback: (movies:[Movie]) -> Void, errorCallback: ((NSError?) -> Void)?) {
        var params:[String:String] = ["api_key": FlicksData.CLIENT_ID]
        params.update(additionalParams)
        let manager = AFHTTPRequestOperationManager()
        manager.GET(
            endpoint,
            parameters: params,
            success: { (operation ,responseObject) -> Void in
                if let results = responseObject["results"] as? NSArray {
                    var movies:[Movie] = []
                    for result in results as! [NSDictionary] {
                        movies.append(Movie(json: result))
                    }
                    successCallback(movies: movies)
                }
            },
            failure: { (operation, requestError) -> Void in
                if let errorCallback = errorCallback {
                    errorCallback(requestError)
                }
            })
    }
    
    public static func loadImageIntoView(url: NSURL, imageView: UIImageView) {
        FlicksData.loadImageIntoView(url, imageView: imageView, success: nil, failure: nil)
    }
    
    public static func loadImageIntoView(url: NSURL, imageView: UIImageView, success: (() -> Void)?, failure: (() -> Void)?) {
        let request = NSURLRequest(URL: url)
        imageView.alpha = 0.0
        imageView.setImageWithURLRequest(request, placeholderImage: nil,
            success: {(NSURLRequest, NSHTTPURLResponse, image: UIImage) -> Void in
                imageView.image = image
                UIView.animateWithDuration(0.6, animations: {() in
                    imageView.alpha = 1.0
                })
                if let success = success {
                    success()
                }
            },
            failure: {(NSURLRequest, NSHTTPURLResponse, NSError) -> Void in
                if let failure = failure {
                    failure()
                }
            })
    }

}