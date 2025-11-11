use std::{hash::Hasher, ops::WrappingAdd};

// All this values you can see here: https://en.bitcoin.it/wiki/RIPEMD-160
global indexes: [[u32; 16]; 5] = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8],
    [3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12],
    [1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2],
    [4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13],
];

global indexes_stroke: [[u32; 16]; 5] = [
    [5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12],
    [6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2],
    [15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13],
    [8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14],
    [12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11],
];

global shifts: [[u32; 16]; 5] = [
    [11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8],
    [7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12],
    [11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5],
    [11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12],
    [9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6],
];

global shifts_stroke: [[u32; 16]; 5] = [
    [8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6],
    [9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11],
    [9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5],
    [15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8],
    [8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11],
];

/// The length of data array must be the same with Field type size (in bytes)
pub struct Ripemd160Hasher<let CAP: u32> {
    data: [u8; CAP],
}

impl<let CAP: u32> Hasher for Ripemd160Hasher<CAP> {
    fn finish(self) -> Field {
        let hash = ripemd160(self.data);
        Field::from_be_bytes(hash)
    }

    fn write(&mut self, input: Field) {
        self.data = input.to_be_bytes();
    }
}

/// Accepts an array of bytes with any length and return 20-bytes array as hash
/// Data must be represented in big-endian order
pub fn ripemd160<let N: u32>(message: [u8; N]) -> [u8; 20] {
    let mut with_added_bytes = message.as_slice().push_back(0x80);

    // Add 0 until data length is 56 mod(64) (than we add raw message length (8 bytes)
    // And have a length that is a multiple of 64 - the processing block size)
    for _ in 0..((64 - ((N + 1) % 64) as i32 - 8 + 64) % 64) {
        with_added_bytes = with_added_bytes.push_back(0);
    }

    // We need to divide the size into two words of 32 bytes
    let start_len = (message.len() as u64) * 8;
    let right_bits = start_len & 0xffffffff;
    let left_bits = (start_len >> 32) & 0xffffffff;

    // First we add low bits (little-endian)
    for i in 0..4 {
        with_added_bytes = with_added_bytes.push_back(((right_bits >> (i * 8)) & 0xff) as u8);
    }
    // Than we add high bits
    for i in 0..4 {
        with_added_bytes = with_added_bytes.push_back(((left_bits >> (i * 8)) & 0xff) as u8);
    }

    // Now we are ready to find the hash
    let mut h0: u32 = 0x67452301;
    let mut h1: u32 = 0xEFCDAB89;
    let mut h2: u32 = 0x98BADCFE;
    let mut h3: u32 = 0x10325476;
    let mut h4: u32 = 0xC3D2E1F0;

    for i in 0..((8 + ((64 - ((N + 1) % 64) as i32 - 8 + 64) % 64) as u32 + N + 1) / 64) {
        let mut A = h0;
        let mut B = h1;
        let mut C = h2;
        let mut D = h3;
        let mut E = h4;

        let mut AS = h0;
        let mut BS = h1;
        let mut CS = h2;
        let mut DS = h3;
        let mut ES = h4;

        let mut words: [u32; 16] = [0; 16];
        for w in 0..16 {
            // Each 'w' is one 32-bit word
            words[w] = (
                (with_added_bytes[i * 64 + w * 4 + 0] as u32) << 0
                    | (with_added_bytes[i * 64 + w * 4 + 1] as u32) << 8
                    | (with_added_bytes[i * 64 + w * 4 + 2] as u32) << 16
                    | (with_added_bytes[i * 64 + w * 4 + 3] as u32) << 24
            );
        }

        let mut T = 0;
        for j in 0..=79 {
            T = A
                .wrapping_add(bit_func(j, B, C, D))
                .wrapping_add(words[indexes[j / 16][j % 16]] as u32)
                .wrapping_add(hex_const(j, false));

            T = rotate_left(T, shifts[j / 16][j % 16]);

            T = T.wrapping_add(E);

            A = E;
            E = D;
            D = rotate_left(C, 10);
            C = B;
            B = T;

            T = AS
                .wrapping_add(bit_func(79 - j, BS, CS, DS))
                .wrapping_add(words[indexes_stroke[j / 16][j % 16]])
                .wrapping_add(hex_const(j, true));

            T = rotate_left(T, shifts_stroke[j / 16][j % 16]);

            T = T.wrapping_add(ES);

            AS = ES;
            ES = DS;
            DS = rotate_left(CS, 10);
            CS = BS;
            BS = T;
        }

        T = h1.wrapping_add(C).wrapping_add(DS);
        h1 = h2.wrapping_add(D).wrapping_add(ES);
        h2 = h3.wrapping_add(E).wrapping_add(AS);
        h3 = h4.wrapping_add(A).wrapping_add(BS);
        h4 = h0.wrapping_add(B).wrapping_add(CS);
        h0 = T;
    }

    // Concat all h with little endian
    let mut res: [u8; 20] = [0; 20];
    for i in 0..4 {
        res[i] = ((h0 >> i * 8) & 0xff) as u8;
    }

    for i in 0..4 {
        res[i + 4] = ((h1 >> i * 8) & 0xff) as u8;
    }

    for i in 0..4 {
        res[i + 8] = ((h2 >> i * 8) & 0xff) as u8;
    }

    for i in 0..4 {
        res[i + 12] = ((h3 >> i * 8) & 0xff) as u8;
    }

    for i in 0..4 {
        res[i + 16] = ((h4 >> i * 8) & 0xff) as u8;
    }

    res
}

/// Shift with saving high bits as low bits (cyclic shift)
fn rotate_left(x: u32, n: u32) -> u32 {
    ((x << n) | (x >> (32 - n))) & 0xffffffff
}

/// Returns result after processing values depending on round num
// (you can see this functions here: https://en.bitcoin.it/wiki/RIPEMD-160)
fn bit_func(j: u32, x: u32, y: u32, z: u32) -> u32 {
    if j < 16 {
        x ^ y ^ z
    } else if j < 32 {
        (x & y) | (!x & z)
    } else if j < 48 {
        (x | !y) ^ z
    } else if j < 64 {
        (x & z) | (y & !z)
    } else {
        x ^ (y | !z)
    }
}

// Returns ripemd160 constant
// (you can see them here: https://en.bitcoin.it/wiki/RIPEMD-160)
fn hex_const(j: u32, stroke: bool) -> u32 {
    if !stroke {
        if j < 16 {
            0x00000000
        } else if j < 32 {
            0x5A827999
        } else if j < 48 {
            0x6ED9EBA1
        } else if j < 64 {
            0x8F1BBCDC
        } else {
            0xA953FD4E
        }
    } else {
        if j < 16 {
            0x50A28BE6
        } else if j < 32 {
            0x5C4DD124
        } else if j < 48 {
            0x6D703EF3
        } else if j < 64 {
            0x7A6D76E9
        } else {
            0x00000000
        }
    }
}

/// Converts bytes array to hex string
pub fn byte_array_to_hex(array: [u8; 20]) -> str<40> {
    let mut res: [u8; 40] = [0; 40];
    for i in 0..array.len() {
        res[2 * i] = array[i] >> 4;

        if res[2 * i] < 10 {
            res[2 * i] = res[2 * i] + 48;
        } else {
            res[2 * i] = res[2 * i] + 55;
        }

        res[2 * i + 1] = array[i] & 0x0F;

        if res[2 * i + 1] < 10 {
            res[2 * i + 1] = res[2 * i + 1] + 48;
        } else {
            res[2 * i + 1] = res[2 * i + 1] + 55;
        }
    }

    res.as_str_unchecked()
}

#[test]
fn test_ripemd160() {
    assert(
        "9C1185A5C5E9FC54612808977EE8F548B2258D31" == byte_array_to_hex(ripemd160("".as_bytes())),
    );

    assert(
        "132072DF690933835EB8B6AD0B77E7B6F14ACAD7"
            == byte_array_to_hex(ripemd160("The quick brown fox jumps over the lazy cog".as_bytes())),
    );

    assert(
        "37F332F68DB77BD9D7EDD4969571AD671CF9DD3B"
            == byte_array_to_hex(ripemd160("The quick brown fox jumps over the lazy dog".as_bytes())),
    );

    assert(
        "07B87D52948E6D4D7630398A0900FA241E197CB5"
            == byte_array_to_hex(ripemd160(
                "The quick brown fox jumps over the lazy dog aaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                    .as_bytes(),
            )),
    );
}

#[test]
fn test_hasher() {
    let message = "The quick brown fox jumps over1";

    let expected_res = "51FBA1A24FBD58CB6E3D2C85A3D2379DE700680C";

    let mut hasher = Ripemd160Hasher { data: [0; 31] };

    hasher.write(Field::from_be_bytes(message.as_bytes()));

    assert(expected_res == byte_array_to_hex(hasher.finish().to_be_bytes()));
}
