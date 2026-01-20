//
//  URLFilterControlProvider.swift
//  FocusFeedURLFilter
//
//  Created by Timo Kuehne on 19.01.26.
//

import NetworkExtension

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
    static let murmurSeed: UInt32 = 0x5F3759DF  // Seed for MurmurHash3

    // MARK: - NEURLFilterControlProvider Protocol

    func fetchPrefilter() async throws -> NEURLFilterPrefilter? {
        // Generate the Bloom filter containing our blocked patterns
        let bloomFilterData = generateBloomFilter(
            patterns: Self.blockedPatterns,
            bitCount: Self.bloomFilterBitCount,
            hashCount: Self.bloomFilterHashCount,
            seed: Self.murmurSeed
        )

        let prefilterData = NEURLFilterPrefilter.PrefilterData.inMemory(bloomFilterData)

        return NEURLFilterPrefilter(
            data: prefilterData,
            bitCount: Self.bloomFilterBitCount,
            hashCount: Self.bloomFilterHashCount,
            murmurSeed: Self.murmurSeed
        )
    }

    func handleVerdict(for url: URL) async -> NEURLFilter.Verdict {
        // Called when Bloom filter has a potential match
        // We need to confirm if this URL should actually be blocked
        // (Bloom filters can have false positives)

        let urlString = url.absoluteString.lowercased()

        for pattern in Self.blockedPatterns {
            if urlString.contains(pattern.lowercased()) {
                // Confirmed match - block this request
                return .drop
            }
        }

        // False positive from Bloom filter - allow the request
        return .allow
    }

    // MARK: - Bloom Filter Generation using MurmurHash3

    private func generateBloomFilter(patterns: [String], bitCount: Int, hashCount: Int, seed: UInt32) -> Data {
        // Create a bit array for the Bloom filter
        let byteCount = (bitCount + 7) / 8
        var filter = [UInt8](repeating: 0, count: byteCount)

        // For each pattern, compute multiple hash positions and set those bits
        for pattern in patterns {
            let positions = hashPositions(for: pattern, bitCount: bitCount, hashCount: hashCount, seed: seed)
            for position in positions {
                let byteIndex = position / 8
                let bitIndex = position % 8
                filter[byteIndex] |= (1 << bitIndex)
            }
        }

        return Data(filter)
    }

    private func hashPositions(for string: String, bitCount: Int, hashCount: Int, seed: UInt32) -> [Int] {
        // Use double hashing technique with MurmurHash3
        // h(i) = (h1 + i * h2) mod m
        // This gives us multiple hash functions from two base hashes

        guard let data = string.data(using: .utf8) else {
            return []
        }

        let bytes = Array(data)

        // Get two hash values using MurmurHash3 with different seeds
        let h1 = murmurHash3(bytes: bytes, seed: seed)
        let h2 = murmurHash3(bytes: bytes, seed: seed &+ 1)

        var positions = [Int]()
        for i in 0..<hashCount {
            let combinedHash = h1 &+ (UInt32(i) &* h2)
            let position = Int(combinedHash % UInt32(bitCount))
            positions.append(position)
        }

        return positions
    }

    // MARK: - MurmurHash3 Implementation (32-bit)

    private func murmurHash3(bytes: [UInt8], seed: UInt32) -> UInt32 {
        let c1: UInt32 = 0xcc9e2d51
        let c2: UInt32 = 0x1b873593
        let length = bytes.count

        var h1 = seed

        // Body - process 4-byte chunks
        let nblocks = length / 4
        for i in 0..<nblocks {
            let offset = i * 4
            var k1 = UInt32(bytes[offset])
            k1 |= UInt32(bytes[offset + 1]) << 8
            k1 |= UInt32(bytes[offset + 2]) << 16
            k1 |= UInt32(bytes[offset + 3]) << 24

            k1 = k1 &* c1
            k1 = (k1 << 15) | (k1 >> 17)  // ROTL32(k1, 15)
            k1 = k1 &* c2

            h1 ^= k1
            h1 = (h1 << 13) | (h1 >> 19)  // ROTL32(h1, 13)
            h1 = h1 &* 5 &+ 0xe6546b64
        }

        // Tail - handle remaining bytes
        let tail = nblocks * 4
        var k1: UInt32 = 0

        switch length & 3 {
        case 3:
            k1 ^= UInt32(bytes[tail + 2]) << 16
            fallthrough
        case 2:
            k1 ^= UInt32(bytes[tail + 1]) << 8
            fallthrough
        case 1:
            k1 ^= UInt32(bytes[tail])
            k1 = k1 &* c1
            k1 = (k1 << 15) | (k1 >> 17)
            k1 = k1 &* c2
            h1 ^= k1
        default:
            break
        }

        // Finalization
        h1 ^= UInt32(length)

        // fmix32
        h1 ^= h1 >> 16
        h1 = h1 &* 0x85ebca6b
        h1 ^= h1 >> 13
        h1 = h1 &* 0xc2b2ae35
        h1 ^= h1 >> 16

        return h1
    }
}
