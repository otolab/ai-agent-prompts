#!/usr/bin/env python3

"""
GitHub Code Search Fragment Line Locator

This script processes GitHub GraphQL code search results and attempts to
locate exact line numbers from code fragments.
"""

import json
import sys
import re
from typing import List, Dict, Any, Optional, Tuple
from difflib import SequenceMatcher

def normalize_code(code: str) -> str:
    """
    Normalize code for comparison by removing extra whitespace.
    """
    # Remove leading/trailing whitespace and normalize internal whitespace
    return re.sub(r'\s+', ' ', code.strip())

def fuzzy_match_score(s1: str, s2: str) -> float:
    """
    Calculate similarity score between two strings.
    """
    return SequenceMatcher(None, s1, s2).ratio()

def find_fragment_in_text(fragment: str, full_text: str) -> List[Tuple[int, str, float]]:
    """
    Find fragment in full text and return line numbers with matched lines and confidence scores.

    Returns:
        List of tuples: (line_number, line_text, confidence_score)
    """
    # Normalize fragment for matching
    fragment_normalized = normalize_code(fragment)
    fragment_lines = fragment.split('\n')

    lines = full_text.split('\n')
    matches = []

    # Strategy 1: Try to find exact normalized match
    for i, line in enumerate(lines, 1):
        line_normalized = normalize_code(line)
        if fragment_normalized in line_normalized:
            matches.append((i, line, 1.0))

    # Strategy 2: Multi-line fragment matching
    if not matches and len(fragment_lines) > 1:
        # Try to match the first line of the fragment
        first_fragment_line = normalize_code(fragment_lines[0])

        for i, line in enumerate(lines, 1):
            line_normalized = normalize_code(line)

            # Check if first line matches
            if first_fragment_line in line_normalized or line_normalized in first_fragment_line:
                # Check subsequent lines
                match_score = 1.0
                matched_lines = [line]

                for j, frag_line in enumerate(fragment_lines[1:], 1):
                    if i + j - 1 < len(lines):
                        next_line = lines[i + j - 1]
                        frag_normalized = normalize_code(frag_line)
                        next_normalized = normalize_code(next_line)

                        # Calculate similarity
                        similarity = fuzzy_match_score(frag_normalized, next_normalized)
                        if similarity > 0.7:  # 70% similarity threshold
                            matched_lines.append(next_line)
                            match_score = min(match_score, similarity)
                        else:
                            break

                # If we matched at least half of the fragment lines
                if len(matched_lines) >= len(fragment_lines) / 2:
                    matches.append((i, line, match_score))

    # Strategy 3: Fuzzy matching for single lines
    if not matches and len(fragment_lines) == 1:
        fragment_words = fragment_normalized.split()

        # Only try fuzzy matching if fragment has meaningful content
        if len(fragment_words) > 2:
            for i, line in enumerate(lines, 1):
                line_normalized = normalize_code(line)

                # Calculate similarity score
                score = fuzzy_match_score(fragment_normalized, line_normalized)

                # If high similarity, add as match
                if score > 0.8:  # 80% similarity threshold
                    matches.append((i, line, score))

    # Strategy 4: Partial matching with key terms
    if not matches:
        # Extract likely important terms (function names, class names, etc.)
        important_terms = re.findall(r'\b(?:class|function|def|const|let|var|public|private|protected)\s+(\w+)', fragment)

        if important_terms:
            for i, line in enumerate(lines, 1):
                # Check if line contains all important terms
                if all(term in line for term in important_terms):
                    matches.append((i, line, 0.6))

    # Sort by confidence score (highest first)
    matches.sort(key=lambda x: x[2], reverse=True)

    return matches

def extract_highlights(text_match: Dict[str, Any]) -> List[str]:
    """
    Extract highlighted text from text match.
    """
    highlights = []
    for highlight in text_match.get('highlights', []):
        text = highlight.get('text', '')
        if text:
            highlights.append(text)
    return highlights

def process_search_results(data: Dict[str, Any]) -> None:
    """
    Process GitHub code search results and locate line numbers from fragments.
    """
    edges = data.get('data', {}).get('search', {}).get('edges', [])

    if not edges:
        print("No search results to process")
        return

    results_with_lines = 0
    total_results = len(edges)

    for edge in edges:
        node = edge.get('node', {})
        text_matches = edge.get('textMatches', [])

        repo = node.get('repository', {}).get('nameWithOwner', '')
        path = node.get('path', '')
        url = node.get('url', '')
        full_text = node.get('text', '')

        if not text_matches:
            continue

        print(f"\n{'='*60}")
        print(f"Repository: {repo}")
        print(f"File: {path}")
        print(f"URL: {url}")

        if not full_text:
            print("⚠️  Warning: Full text not available for line number detection")
            continue

        found_any_match = False

        for match_idx, match in enumerate(text_matches, 1):
            fragment = match.get('fragment', '')
            if not fragment:
                continue

            # Show fragment preview
            fragment_preview = fragment.replace('\n', '\\n')
            if len(fragment_preview) > 100:
                fragment_preview = fragment_preview[:100] + "..."

            print(f"\n📝 Fragment {match_idx}: {fragment_preview}")

            # Extract highlights if available
            highlights = extract_highlights(match)
            if highlights:
                print(f"   Highlights: {', '.join(highlights[:3])}")

            # Find line numbers
            line_matches = find_fragment_in_text(fragment, full_text)

            if line_matches:
                found_any_match = True
                print("📍 Located at:")

                # Show up to 3 best matches
                for line_num, line_text, confidence in line_matches[:3]:
                    # Construct GitHub URL with line number
                    line_url = f"{url}#L{line_num}"

                    # Truncate long lines
                    line_preview = line_text.strip()
                    if len(line_preview) > 80:
                        line_preview = line_preview[:80] + "..."

                    confidence_indicator = "✓✓✓" if confidence > 0.9 else "✓✓" if confidence > 0.7 else "✓"
                    print(f"   Line {line_num} {confidence_indicator}: {line_preview}")
                    print(f"   → {line_url}")
            else:
                print("   ❌ Could not locate exact line numbers")

        if found_any_match:
            results_with_lines += 1

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary: Located line numbers for {results_with_lines}/{total_results} files")

def main():
    """
    Main entry point - read JSON from stdin and process results.
    """
    try:
        # Check if stdin has data
        if sys.stdin.isatty():
            print("Error: No input data. This script expects JSON data via stdin.", file=sys.stderr)
            print("Usage: gh api graphql -f query='...' | python3 locate_lines_from_fragment.py", file=sys.stderr)
            sys.exit(1)

        # Read and parse JSON
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            print("Error: Empty input", file=sys.stderr)
            sys.exit(1)

        data = json.loads(raw_input)
        process_search_results(data)

    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        print("Make sure the input is valid JSON from GitHub GraphQL API", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()