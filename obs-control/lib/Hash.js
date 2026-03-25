.pragma library

const INITIAL_STATE = [
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
]

const ROUND_CONSTANTS = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]

function rotateRight(value, amount) {
  return (value >>> amount) | (value << (32 - amount))
}

function add32() {
  let result = 0

  for (let index = 0; index < arguments.length; index += 1) {
    result = (result + arguments[index]) >>> 0
  }

  return result
}

function utf8Bytes(input) {
  const text = String(input ?? "")
  const bytes = []

  for (let index = 0; index < text.length; index += 1) {
    let codePoint = text.charCodeAt(index)

    if (codePoint >= 0xd800 && codePoint <= 0xdbff && index + 1 < text.length) {
      const low = text.charCodeAt(index + 1)
      if (low >= 0xdc00 && low <= 0xdfff) {
        codePoint = 0x10000 + ((codePoint - 0xd800) << 10) + (low - 0xdc00)
        index += 1
      }
    }

    if (codePoint <= 0x7f) {
      bytes.push(codePoint)
      continue
    }

    if (codePoint <= 0x7ff) {
      bytes.push(0xc0 | (codePoint >> 6))
      bytes.push(0x80 | (codePoint & 0x3f))
      continue
    }

    if (codePoint <= 0xffff) {
      bytes.push(0xe0 | (codePoint >> 12))
      bytes.push(0x80 | ((codePoint >> 6) & 0x3f))
      bytes.push(0x80 | (codePoint & 0x3f))
      continue
    }

    bytes.push(0xf0 | (codePoint >> 18))
    bytes.push(0x80 | ((codePoint >> 12) & 0x3f))
    bytes.push(0x80 | ((codePoint >> 6) & 0x3f))
    bytes.push(0x80 | (codePoint & 0x3f))
  }

  return bytes
}

function bytesToBase64(bytes) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let result = ""

  for (let index = 0; index < bytes.length; index += 3) {
    const byte1 = bytes[index]
    const byte2 = index + 1 < bytes.length ? bytes[index + 1] : 0
    const byte3 = index + 2 < bytes.length ? bytes[index + 2] : 0
    const chunk = (byte1 << 16) | (byte2 << 8) | byte3

    result += alphabet[(chunk >> 18) & 0x3f]
    result += alphabet[(chunk >> 12) & 0x3f]
    result += index + 1 < bytes.length ? alphabet[(chunk >> 6) & 0x3f] : "="
    result += index + 2 < bytes.length ? alphabet[chunk & 0x3f] : "="
  }

  return result
}

function sha256Bytes(input) {
  const message = utf8Bytes(input)
  const bitLength = message.length * 8
  const words = new Array(64)
  const state = INITIAL_STATE.slice()

  message.push(0x80)

  while ((message.length % 64) !== 56) {
    message.push(0)
  }

  const high = Math.floor(bitLength / 0x100000000)
  const low = bitLength >>> 0

  message.push((high >>> 24) & 0xff)
  message.push((high >>> 16) & 0xff)
  message.push((high >>> 8) & 0xff)
  message.push(high & 0xff)
  message.push((low >>> 24) & 0xff)
  message.push((low >>> 16) & 0xff)
  message.push((low >>> 8) & 0xff)
  message.push(low & 0xff)

  for (let offset = 0; offset < message.length; offset += 64) {
    for (let index = 0; index < 16; index += 1) {
      const wordOffset = offset + (index * 4)
      words[index] = ((message[wordOffset] << 24)
                      | (message[wordOffset + 1] << 16)
                      | (message[wordOffset + 2] << 8)
                      | message[wordOffset + 3]) >>> 0
    }

    for (let index = 16; index < 64; index += 1) {
      const s0 = rotateRight(words[index - 15], 7)
                 ^ rotateRight(words[index - 15], 18)
                 ^ (words[index - 15] >>> 3)
      const s1 = rotateRight(words[index - 2], 17)
                 ^ rotateRight(words[index - 2], 19)
                 ^ (words[index - 2] >>> 10)

      words[index] = add32(words[index - 16], s0, words[index - 7], s1)
    }

    let a = state[0]
    let b = state[1]
    let c = state[2]
    let d = state[3]
    let e = state[4]
    let f = state[5]
    let g = state[6]
    let h = state[7]

    for (let index = 0; index < 64; index += 1) {
      const sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
      const choose = (e & f) ^ ((~e) & g)
      const temp1 = add32(h, sum1, choose, ROUND_CONSTANTS[index], words[index])
      const sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
      const majority = (a & b) ^ (a & c) ^ (b & c)
      const temp2 = add32(sum0, majority)

      h = g
      g = f
      f = e
      e = add32(d, temp1)
      d = c
      c = b
      b = a
      a = add32(temp1, temp2)
    }

    state[0] = add32(state[0], a)
    state[1] = add32(state[1], b)
    state[2] = add32(state[2], c)
    state[3] = add32(state[3], d)
    state[4] = add32(state[4], e)
    state[5] = add32(state[5], f)
    state[6] = add32(state[6], g)
    state[7] = add32(state[7], h)
  }

  const digest = []

  for (let index = 0; index < state.length; index += 1) {
    digest.push((state[index] >>> 24) & 0xff)
    digest.push((state[index] >>> 16) & 0xff)
    digest.push((state[index] >>> 8) & 0xff)
    digest.push(state[index] & 0xff)
  }

  return digest
}

function sha256Base64(input) {
  return bytesToBase64(sha256Bytes(input))
}
