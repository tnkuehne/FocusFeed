//
//  URLFilterControlProvider.swift
//  FocusFeedURLFilter
//
//  Created by Timo Kuehne on 19.01.26.
//

import ExtensionFoundation
import NetworkExtension
import CryptoKit

@main
class URLFilterControlProvider: NEURLFilterControlProvider {

    // URL patterns to block for YouTube Shorts
    static let blockedPatterns = [
        "/shorts/",
        "/youtubei/v1/reel/",
        "el=shortspage",
        "reel_watch_sequence",
        "reel_item_watch"
    ]

    // Bloom filter parameters
    // For a small set of patterns, we use a modest filter size
    static let bloomFilterBitCount = 4096
    static let bloomFilterHashCount = 4

    required internal init() {
    }

    func start() async throws {
        // Extension started
    }

    func stop(reason: NEProviderStopReason) async throws {
        // Extension stopped
    }

    override func fetchPrefilter() async throws -> NEURLFilterPrefilter? {
        // Generate the Bloom filter containing our blocked patterns
        let bloomFilterData = generateBloomFilter(
            patterns: Self.blockedPatterns,
            bitCount: Self.bloomFilterBitCount,
            hashCount: Self.bloomFilterHashCount
        )

        let prefilterData = NEURLFilterPrefilter.PrefilterData.inMemory(bloomFilterData)

        return NEURLFilterPrefilter(
            data: prefilterData,
            bitCount: Self.bloomFilterBitCount,
            hashCount: Self.bloomFilterHashCount
        )
    }

    override func handleVerdict(
        for url: URL,
        completionHandler: @escaping (NEURLFilterVerdict) -> Void
    ) {
        // Called when Bloom filter has a potential match
        // We need to confirm if this URL should actually be blocked
        // (Bloom filters can have false positives)

        let urlString = url.absoluteString.lowercased()

        for pattern in Self.blockedPatterns {
            if urlString.contains(pattern.lowercased()) {
                // Confirmed match - block this request
                completionHandler(.drop)
                return
            }
        }

        // False positive from Bloom filter - allow the request
        completionHandler(.allow)
    }

    // MARK: - Bloom Filter Generation

    private func generateBloomFilter(patterns: [String], bitCount: Int, hashCount: Int) -> Data {
        // Create a bit array for the Bloom filter
        let byteCount = (bitCount + 7) / 8
        var filter = [UInt8](repeating: 0, count: byteCount)

        // For each pattern, compute multiple hash positions and set those bits
        for pattern in patterns {
            let positions = hashPositions(for: pattern, bitCount: bitCount, hashCount: hashCount)
            for position in positions {
                let byteIndex = position / 8
                let bitIndex = position % 8
                filter[byteIndex] |= (1 << bitIndex)
            }
        }

        return Data(filter)
    }

    private func hashPositions(for string: String, bitCount: Int, hashCount: Int) -> [Int] {
        // Use double hashing technique with SHA256
        // h(i) = (h1 + i * h2) mod m
        // This gives us multiple hash functions from two base hashes

        guard let data = string.data(using: .utf8) else {
            return []
        }

        // Get SHA256 hash and split into two 128-bit halves
        let hash = SHA256.hash(data: data)
        let hashBytes = Array(hash)

        // Use first 8 bytes for h1, next 8 bytes for h2
        let h1 = hashBytes[0..<8].reduce(0) { result, byte in
            (result << 8) | UInt64(byte)
        }
        let h2 = hashBytes[8..<16].reduce(0) { result, byte in
            (result << 8) | UInt64(byte)
        }

        var positions = [Int]()
        for i in 0..<hashCount {
            let combinedHash = h1 &+ (UInt64(i) &* h2)
            let position = Int(combinedHash % UInt64(bitCount))
            positions.append(position)
        }

        return positions
    }
}
