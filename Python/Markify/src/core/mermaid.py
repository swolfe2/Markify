"""
Mermaid diagram utilities for Markify.
Generates clickable links to mermaid.live for diagram visualization.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import base64
import json
import re
import zlib
from typing import List, Tuple


def encode_mermaid_for_url(diagram_code: str) -> str:
    """
    Encode a Mermaid diagram for use in a mermaid.live URL.
    
    Uses pako-compatible compression (zlib) + base64 encoding.
    
    Args:
        diagram_code: The raw Mermaid diagram code
        
    Returns:
        URL-safe encoded string for mermaid.live
    """
    # Create the JSON payload that mermaid.live expects
    payload = json.dumps({
        "code": diagram_code,
        "mermaid": {"theme": "default"}
    })
    
    # Compress with zlib (pako-compatible)
    compressed = zlib.compress(payload.encode('utf-8'), level=9)
    
    # Base64 encode and make URL-safe
    encoded = base64.urlsafe_b64encode(compressed).decode('ascii')
    
    # Remove padding (mermaid.live doesn't use it)
    encoded = encoded.rstrip('=')
    
    return encoded


def generate_mermaid_link(diagram_code: str) -> str:
    """
    Generate a clickable mermaid.live link for a diagram.
    
    Args:
        diagram_code: The raw Mermaid diagram code
        
    Returns:
        Full URL to view/edit the diagram on mermaid.live
    """
    encoded = encode_mermaid_for_url(diagram_code)
    return f"https://mermaid.live/edit#pako:{encoded}"


def add_mermaid_links_to_markdown(markdown_content: str) -> str:
    """
    Process markdown content and add mermaid.live links after mermaid code blocks.
    
    Args:
        markdown_content: The markdown text to process
        
    Returns:
        Markdown with clickable links added after mermaid blocks
    """
    # Pattern to match mermaid code blocks
    # Matches ```mermaid followed by content until closing ```
    pattern = r'```mermaid\s*\n(.*?)```'
    
    def add_link(match: re.Match) -> str:
        diagram_code = match.group(1).strip()
        original_block = match.group(0)
        
        # Generate the link
        link = generate_mermaid_link(diagram_code)
        
        # Add the link after the code block
        return f"{original_block}\n\n[📊 View Diagram on mermaid.live]({link})"
    
    # Replace all mermaid blocks with enhanced versions
    result = re.sub(pattern, add_link, markdown_content, flags=re.DOTALL)
    
    return result


def find_mermaid_blocks(markdown_content: str) -> List[Tuple[str, str]]:
    """
    Find all mermaid code blocks in markdown content.
    
    Args:
        markdown_content: The markdown text to search
        
    Returns:
        List of tuples: (diagram_code, mermaid_live_link)
    """
    pattern = r'```mermaid\s*\n(.*?)```'
    matches = re.findall(pattern, markdown_content, flags=re.DOTALL)
    
    results = []
    for diagram_code in matches:
        diagram_code = diagram_code.strip()
        link = generate_mermaid_link(diagram_code)
        results.append((diagram_code, link))
    
    return results
