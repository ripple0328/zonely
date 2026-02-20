import XCTest
@testable import say_my_name

final class PronounceServiceTests: XCTestCase {
    func testPronounce_parsesAudio() async throws {
        let json = #"{"type":"audio","url":"https://example.com/a.mp3"}"#.data(using: .utf8)!
        let session = URLSession.mock(json: json)
        let svc = PronounceService(session: session)
        let result = try await svc.pronounce(text: "abc", lang: "en-US")
        switch result {
        case .audio(let url): XCTAssertEqual(url.absoluteString, "https://example.com/a.mp3")
        default: XCTFail("Expected audio")
        }
    }
}

// MARK: - URLSession Mock
extension URLSession {
    static func mock(status: Int = 200, json: Data) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.responseData = json
        MockURLProtocol.statusCode = status
        return URLSession(configuration: config)
    }
}

final class MockURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}


