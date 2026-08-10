# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
with open('test/fixtures/all_types.tar', 'rb') as f:
    while True:
        block = f.read(512)
        if not block or block == b'\x00'*512:
            break
        name = block[0:100].rstrip(b'\x00').decode()
        size = int(block[124:135].rstrip(b'\x00 ') or b'0', 8)
        typeflag = chr(block[156])
        print(f'[{typeflag}] {name!r}  size={size}')
        padded = (size + 511) // 512 * 512
        f.read(padded)
