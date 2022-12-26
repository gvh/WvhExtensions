//
//  NSURLSession+Synchronous.swift
//  WvhExtensions
//
//  Created by Gardner von Holt on 2015/Dec/14.
//  Copyright © 2015-2023 Gardner von Holt. All rights reserved.
//

import Foundation

// NSURLSession synchronous behavior

public extension URLSession {

    static func requestSynchronousDataUrl(_ url: URL) -> Data? {
        let request = URLRequest(url: url)
        var data: Data?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request, completionHandler: { (responseData, _, _) -> Void in
            data = responseData! // treat optionals properly
            semaphore.signal()
            }) .resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return data
    }

    /// Return data from synchronous URL request
    static func requestSynchronousData(_ request: URLRequest) -> Data? {
        var data: Data?
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { taskData, _, error -> Void in
            data = taskData
            if data == nil, let error = error {
                print(error.localizedDescription)
            }
            semaphore.signal()
        })
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return data
    }

    /// Return data synchronous from specified endpoint
    static func requestSynchronousDataWithURLString(_ requestString: String) -> Data? {
        guard let url = URL(string: requestString) else { return nil }
        let request = URLRequest(url: url)
        return URLSession.requestSynchronousData(request)
    }

    /// Return JSON synchronous from URL request
    static func requestSynchronousJSON(_ request: URLRequest) -> AnyObject? {
        guard let data = URLSession.requestSynchronousData(request) else { return nil }
        return try! JSONSerialization.jsonObject(with: data, options: []) as AnyObject?
    }

    /// Return JSON synchronous from specified endpoint
    static func requestSynchronousJSONWithURLString(_ requestString: String) -> AnyObject? {
        guard let url = URL(string: requestString) else { return nil }
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return URLSession.requestSynchronousJSON(request as URLRequest)
    }

}
