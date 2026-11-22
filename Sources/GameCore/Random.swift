// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The one random number generator the game uses: seedable, and Codable so that
/// a saved match resumes with the same sequence. Every module that needs
/// randomness takes it from here; `SystemRandomNumberGenerator` cannot be seeded
/// and must not be used in the simulation, the map generator or the computer
/// player. The algorithm is xoshiro256**, seeded through SplitMix64.
public struct SeededGenerator: RandomNumberGenerator, Codable, Sendable, Hashable {
    private var s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64

    public init(seed: UInt64) {
        var x = seed
        func splitMix() -> UInt64 {
            x &+= 0x9E37_79B9_7F4A_7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        s0 = splitMix(); s1 = splitMix(); s2 = splitMix(); s3 = splitMix()
    }

    public mutating func next() -> UInt64 {
        let result = rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 45)
        return result
    }

    /// A new generator whose sequence is independent of this one's, for handing
    /// a sub-system its own stream without disturbing this one's order.
    public mutating func split() -> SeededGenerator { SeededGenerator(seed: next()) }

    private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 { (x << k) | (x >> (64 - k)) }
}

/// A checksum over bytes, for determinism tests: FNV-1a, 64 bits. Unlike
/// `Hasher`, it gives the same value in every process.
public struct StableChecksum: Sendable {
    public private(set) var value: UInt64 = 0xCBF2_9CE4_8422_2325

    public init() {}

    public mutating func add<S: Sequence>(bytes: S) where S.Element == UInt8 {
        for byte in bytes {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01B3
        }
    }

    public mutating func add(_ string: String) { add(bytes: string.utf8) }
}
