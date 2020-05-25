//
//  Application+Testable.swift
//  SwiftyBot
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 - 2019 Fabrizio Brancati.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Bot
import Foundation
import Vapor

// swiftlint:disable explicit_acl

/// Structure of `ErrorMiddleware` default response.
internal struct ErrorResponse: Codable {
    /// Always `true` to indicate this is a non-typical JSON response.
    internal var error: Bool

    /// The reason for the error.
    internal var reason: String
}

internal extension Application {
    static func bot(envArgs _: [String]? = nil) throws -> Application {
        try app(.testing)
    }

    static func testable(envArgs: [String]? = nil) throws -> Application {
        var config = Config.default()
        var services = Services.default()
        var env = Environment.testing

        if let environmentArgs = envArgs {
            env.arguments = environmentArgs
        }

        try configure(&config, &env, &services)

        let app = try Application(config: config, environment: env, services: services)

        try boot(app)
        return app
    }

    func sendRequest(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init(), body: HTTPBody = .init()) throws -> Response {
        let responder = try make(Responder.self)
        var path = path

        if method == .GET, let data = body.data, var stringData = String(data: data, encoding: .utf8) {
            stringData = stringData.replacingOccurrences(of: ":", with: "=")
            stringData = stringData.replacingOccurrences(of: ",", with: "&")
            stringData = stringData.replacingOccurrences(of: "}", with: "")
            stringData = stringData.replacingOccurrences(of: "\"", with: "")
            path += stringData.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
            path = path.replacingOccurrences(of: "%7B", with: "?")
        }

        guard let url = URL(string: path) else {
            throw Abort(.badRequest, reason: "Missing data.")
        }

        let request = HTTPRequest(method: method, url: url, headers: headers, body: body)
        let wrappedRequest = Request(http: request, using: self)

        return try responder.respond(to: wrappedRequest).wait()
    }

    func getResponse<T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), body: HTTPBody = .init(), decodeTo type: T.Type) throws -> T where T: Decodable {
        let response = try sendRequest(to: path, method: method, headers: headers, body: body)

        let data = response.http.body.data ?? response.http.status.reasonPhrase.data(using: .utf8) ?? Data()

        guard type == String.self, let string = String(data: data, encoding: .utf8) as? T else {
            return try JSONDecoder().decode(type, from: data)
        }
        return string
    }

    func getResponse<T, U>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), data: U, decodeTo type: T.Type) throws -> T where T: Decodable, U: Encodable {
        let body = try HTTPBody(data: JSONEncoder().encode(data))

        return try getResponse(to: path, method: method, headers: headers, body: body, decodeTo: type)
    }

    func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders, data: T) throws where T: Encodable {
        let body = try HTTPBody(data: JSONEncoder().encode(data))

        _ = try sendRequest(to: path, method: method, headers: headers, body: body)
    }
}
