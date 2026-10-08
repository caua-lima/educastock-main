#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

file_path = r'c:\projetos\PI_Casa_da_Crianca_Estoque\educastock\lib\features\reports\presentation\pages\reports_page.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

print("File read successfully")
print(f"File size: {len(content)} characters")

# Split into lines
lines = content.splitlines(keepends=True)
print(f"Total lines: {len(lines)}")

# Strategy: Find the orphan blocks using regex patterns and remove them

# First, find where "_ChartNote" appears with the specific text
# This is part of the orphan code

orphan_start_pattern = r"(\s+child: Icon\(icon, color: Colors\.white, size: 18\),\n)(\s+\),\n\s+const _ChartNote\()"

# Replace the orphan blocks
# After "child: Icon(icon, color: Colors.white, size: 18)," should come proper _SectionHeader code

# Let's use a more targeted approach: find all instances of orphan patterns
# and reconstruct the file properly

# The orphan code starts after line containing 'child: Icon(icon, color: Colors.white, size: 18),'
# and goes until we find 'class _SectionHeader extends StatelessWidget {' (the second one)

# Find the first '_SectionHeader' class definition line
first_sectionheader = None
for i, line in enumerate(lines):
    if 'class _SectionHeader extends StatelessWidget {' in line:
        if first_sectionheader is None:
            first_sectionheader = i
        else:
            # This is the second one - the real one
            print(f"Found duplicate _SectionHeader at line {i+1}")
            # Remove everything from after the first Icon(...) line up to line i-1
            break

# Actually, let's just remove lines with obvious orphan patterns
filtered_lines = []
skip_until_line = -1

for i, line in enumerate(lines):
    current_line_num = i + 1
    
    # Skip orphan code patterns
    if skip_until_line > current_line_num:
        continue
    
    # Check for orphan patterns
    if re.search(r'const _ChartNote\(', line) and 'A barra mostra' in lines[i] if i < len(lines) else False:
        # This is part of orphan code - skip next several lines
        j = i
        while j < len(lines) and not re.search(r'class _.*extends', lines[j]):
            j += 1
        skip_until_line = j
        continue
    
    filtered_lines.append(line)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(filtered_lines)

print("✓ File processing attempted")

