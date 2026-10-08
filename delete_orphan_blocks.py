#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

file_path = r'c:\projetos\PI_Casa_da_Crianca_Estoque\educastock\lib\features\reports\presentation\pages\reports_page.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'Original file: {len(lines)} lines')

# The file currently has orphan code mixed in
# We need to remove it by pattern matching

# Step 1: Find and remove orphan code within _SectionHeader.build()
# The orphan code is characterized by having code like:
# "const _ChartNote(" with "A barra mostra" text
# "riskCountsAsync.when(" 
# "riskPredictionsAsync.when("
# These should not be in the build() method

# Find the first _SectionHeader class definition
first_sectionheader_line = -1
for i, line in enumerate(lines):
    if 'class _SectionHeader extends StatelessWidget {' in line:
        if first_sectionheader_line == -1:
            first_sectionheader_line = i
        else:
            print(f"Found second _SectionHeader at line {i + 1}")
            # Remove everything from first_sectionheader_line to i-1
            # Keep the second one
            break

if first_sectionheader_line > 0:
    # Find the end of the first (incorrect) _SectionHeader
    # Look for "}" that closes the class
    end_of_first = -1
    brace_count = 0
    for i in range(first_sectionheader_line, len(lines)):
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0 and i > first_sectionheader_line:
            end_of_first = i
            break
    
    if end_of_first > 0:
        print(f"Removing duplicate _SectionHeader from line {first_sectionheader_line + 1} to {end_of_first + 1}")
        # Remove these lines
        lines = lines[:first_sectionheader_line] + lines[end_of_first + 1:]

print(f'After removing duplicate _SectionHeader: {len(lines)} lines')

# Step 2: Remove the _MovementsSection class at the end
target_marker = 'Seção de movimentações por período'
block2_start = -1
for i, line in enumerate(lines):
    if target_marker in line:
        block2_start = i
        print(f"Found Block 2 marker at line {i + 1}")
        break

if block2_start >= 0:
    # Find the start of this comment block (should be the line with the comment marker)
    # Go back to find "// ───"
    comment_start = block2_start
    while comment_start > 0 and '//' not in lines[comment_start]:
        comment_start -= 1
    
    print(f"Removing _MovementsSection from line {comment_start + 1} to end of file")
    lines = lines[:comment_start]

print(f'After removing _MovementsSection: {len(lines)} lines')

# Write the file back
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f'✓ File updated successfully')

# Verify
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'\n--- Verification ---')
print(f'Final line count: {len(lines)} lines')

# Check for _SectionHeader class count
section_header_count = sum(1 for line in lines if 'class _SectionHeader' in line)
print(f'Number of _SectionHeader classes: {section_header_count} (should be 1)')

print(f'Does file contain "_MovementsSection"? {"YES - ERROR!" if any("_MovementsSection" in line for line in lines) else "NO - Good!"}')
print(f'Does file contain "_SectionHeader"? {"YES - Good!" if any("_SectionHeader" in line for line in lines) else "NO - ERROR!"}')
print(f'Does file contain "_MovementsTab"? {"YES - Good!" if any("_MovementsTab" in line for line in lines) else "NO - ERROR!"}')
