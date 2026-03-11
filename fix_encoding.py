import sys, io, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Build char->byte reverse map for CP1252
# For bytes 0x80-0xFF, map the unicode char back to the byte value
char_to_byte = {}
for b in range(0x00, 0x100):
    try:
        ch = bytes([b]).decode('cp1252')
        char_to_byte[ch] = b
    except:
        pass

# Also handle the 5 undefined CP1252 bytes (0x81,0x8D,0x8F,0x90,0x9D)
# These map to the same Unicode codepoints (U+0081, etc.) as Latin-1
for b in [0x81, 0x8D, 0x8F, 0x90, 0x9D]:
    char_to_byte[chr(b)] = b

def is_mojibake_char(ch):
    """Check if char could be part of a mojibake sequence (byte >= 0x80)"""
    return char_to_byte.get(ch, 0) >= 0x80

def try_decode(chars):
    """Try to encode chars as CP1252 bytes and decode as UTF-8"""
    try:
        raw = bytes(char_to_byte.get(c, ord(c)) for c in chars)
        return raw.decode('utf-8')
    except (UnicodeDecodeError, KeyError, ValueError):
        return None

result = []
i = 0
fixes = 0
n = len(content)

while i < n:
    if is_mojibake_char(content[i]):
        # Try windows from longest to shortest
        best = None
        for window in range(4, 1, -1):
            if i + window > n:
                continue
            chunk = content[i:i+window]
            decoded = try_decode(chunk)
            if decoded and len(decoded) < len(chunk):
                # Valid decode that's shorter = real UTF-8 recovery
                best = (window, decoded)
                break
        
        if best:
            window, decoded = best
            result.append(decoded)
            fixes += 1
            i += window
            continue
    
    result.append(content[i])
    i += 1

fixed = ''.join(result)

with open('lib/main.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(fixed)

print(f'Fixed {fixes} mojibake sequences')

# Verify
remaining_e2 = len(re.findall('\u00e2', fixed))
remaining_c2 = len(re.findall('\u00c2', fixed))
print(f'Remaining \\u00e2: {remaining_e2}')
print(f'Remaining \\u00c2: {remaining_c2}')

# Show sample of any remaining
for m in list(re.finditer('\u00e2', fixed))[:5]:
    p = m.start()
    print(f'  \\u00e2 at {p}: {repr(fixed[p:p+6])}')
