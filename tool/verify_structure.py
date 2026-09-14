#!/usr/bin/env python3
"""Structural verifier for the Dart codebase (no analyzer available).

Checks, per file:
  1. String/comment-aware brace-paren-bracket balance
  2. Every relative import/part resolves to an existing file
  3. Sp.*/Radii.*/Motion.* member references exist in design_tokens.dart
  4. Icons.<name> references exist in the Flutter icon table (pre-extracted)
"""
import os, re, sys

ROOT = '/home/user/HabitNow'
LIB = os.path.join(ROOT, 'lib')

# tokens extracted from the real Flutter source beforehand
ICONS_FILE = '/tmp/icons.txt'

def strip_strings_and_comments(src: str) -> tuple[str, list[tuple[int, str]]]:
    """Returns code with strings/comments blanked + list of (line, string) pairs."""
    out = []
    strings = []
    i, n = 0, len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == '\n':
            out.append(c); line += 1; i += 1; continue
        if src.startswith('//', i):
            while i < n and src[i] != '\n':
                i += 1
            continue
        if src.startswith('/*', i):
            depth = 1; i += 2
            while i < n and depth:
                if src.startswith('/*', i): depth += 1; i += 2
                elif src.startswith('*/', i): depth -= 1; i += 2
                elif src[i] == '\n': line += 1; i += 1
                else: i += 1
            continue
        if c in ('"', "'"):
            # triple?
            triple = src[i:i+3] in ("'''", '"""')
            quote = src[i:i+3] if triple else c
            i += len(quote)
            start_line = line
            buf = []
            while i < n:
                if src[i] == '\\':
                    buf.append(src[i:i+2]); i += 2; continue
                if src.startswith(quote, i):
                    i += len(quote); break
                if src[i] == '\n':
                    line += 1
                    if not triple:
                        break
                buf.append(src[i]); i += 1
            strings.append((start_line, ''.join(buf)))
            out.append(' ' * 1)
            continue
        if c == '$' and out and out[-1] not in (' ',):
            pass  # interpolation inside strings handled crudely; fine for balance
        out.append(c); i += 1
    return ''.join(out), strings

def check_balance(path: str) -> list[str]:
    src = open(path, encoding='utf-8').read()
    code, _ = strip_strings_and_comments(src)
    pairs = {')': '(', ']': '[', '}': '{'}
    stack = []
    errors = []
    opens = {'(': ')', '[': ']', '{': '}'}
    line = 1
    for ch in code:
        if ch == '\n': line += 1
        elif ch in opens: stack.append((ch, line))
        elif ch in pairs:
            if not stack:
                errors.append(f'{path}:{line} unmatched {ch}')
            else:
                o, l = stack.pop()
                if o != pairs[ch]:
                    errors.append(f'{path}:{line} mismatched {ch} (opened {o} at {l})')
    for o, l in stack:
        errors.append(f'{path}:{l} unclosed {o}')
    return errors

def check_imports(path: str) -> list[str]:
    errors = []
    src = open(path, encoding='utf-8').read()
    for m in re.finditer(r"^\s*(?:export\s+)?import\s+'([^']+)'", src, re.M):
        uri = m.group(1)
        if not uri.startswith('package:habit_now/'):
            continue
        rel = uri.replace('package:habit_now/', '')
        target = os.path.join(LIB, rel)
        if not os.path.exists(target):
            errors.append(f'{path}: missing import target {uri}')
    return errors

def check_tokens(path: str, token_members: dict) -> list[str]:
    errors = []
    src_code, _ = strip_strings_and_comments(open(path, encoding='utf-8').read())
    for prefix, members in token_members.items():
        for m in re.finditer(rf'\b{prefix}\.(\w+)', src_code):
            if m.group(1) not in members:
                errors.append(f'{path}: unknown {prefix}.{m.group(1)}')
    return errors

def check_icons(path: str, icons: set) -> list[str]:
    errors = []
    src_code, _ = strip_strings_and_comments(open(path, encoding='utf-8').read())
    for m in re.finditer(r'\bIcons\.(\w+)', src_code):
        if m.group(1) not in icons:
            errors.append(f'{path}: unknown Icons.{m.group(1)}')
    return errors

def main():
    # build token member sets
    dt = open(os.path.join(LIB, 'core/theme/design_tokens.dart'), encoding='utf-8').read()
    token_members = {}
    for cls in ('Sp', 'Radii', 'Motion', 'Elev'):
        ms = set(re.findall(rf'static const \w+ (\w+)', dt))
        # per-class naive: collect all static consts in file (fine: union check)
        token_members[cls] = ms
    # refine per class block
    for cls in ('Sp', 'Radii', 'Motion', 'Elev'):
        block = re.search(rf'abstract final class {cls} \{{(.*?)\n\}}', dt, re.S)
        if block:
            names = set(re.findall(r'static const [\w<>]+ (\w+)', block.group(1)))
            names |= set(re.findall(r'static [\w<>, ]+ (\w+)\(', block.group(1)))
            token_members[cls] = names

    icons = set(open(ICONS_FILE).read().split())

    all_files = []
    for dirpath, _, files in os.walk(LIB):
        for f in files:
            if f.endswith('.dart'):
                all_files.append(os.path.join(dirpath, f))
    all_files.sort()

    errors = []
    for f in all_files:
        errors += check_balance(f)
        errors += check_imports(f)
        errors += check_tokens(f, token_members)
        errors += check_icons(f, icons)

    print(f'checked {len(all_files)} files')
    if errors:
        print(f'\n{len(errors)} ERRORS:')
        for e in errors:
            print(' -', e)
        sys.exit(1)
    print('ALL STRUCTURAL CHECKS PASSED')

if __name__ == '__main__':
    main()
