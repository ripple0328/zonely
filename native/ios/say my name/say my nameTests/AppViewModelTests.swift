import XCTest
@testable import say_my_name

final class AppViewModelTests: XCTestCase {
    func testPlaySetsProviderAndPlayingForAudio() async {
        let network = MockNetwork(result: .audio(URL(string: "https://example.com/a.mp3")!))
        let audio = MockAudio()
        let vm = AppViewModel(network: network, audio: audio)
        let item = LangItem(bcp47: "en-US", text: "Alice")
        let exp = expectation(description: "played")
        audio.playCallback = { exp.fulfill() }
        vm.play(item, displayName: "Alice")
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(vm.providerKinds[item.id], .human)
        XCTAssertEqual(vm.playingPill, item.id)
    }
}

// MARK: - Mocks
final class MockNetwork: PronounceNetworking {
    let toReturn: PronounceOutcome
    init(result: PronounceOutcome) { self.toReturn = result }
    func pronounce(text: String, lang: String) async throws -> PronounceOutcome { toReturn }
}

final class MockAudio: AudioPlaying {
    var onFinish: (() -> Void)?
    var playCallback: (() -> Void)?
    func play(url: URL, lang: String?) async throws { playCallback?(); onFinish?() }
    func playSequence(urls: [URL], lang: String?) async throws { playCallback?(); onFinish?() }
    func speak(text: String, bcp47: String) async throws { playCallback?(); onFinish?() }
}


