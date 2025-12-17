"""
DAX Formatter API integration.
Formats DAX code using the daxformatter.com service.
"""

import urllib.request
import urllib.parse
import urllib.error
import re


def format_dax(code: str, region: str = "US", timeout: int = 5) -> str:
    """
    Format DAX code using daxformatter.com API.
    
    Args:
        code: Raw DAX code to format
        region: "US", "UK", or "EU" (affects list/decimal separators)
        timeout: Request timeout in seconds
    
    Returns:
        Formatted DAX code, or original code if API call fails
    """
    if not code or not code.strip():
        return code
    
    # API endpoint
    url = "https://www.daxformatter.com/"
    
    # Prepare POST data
    data = urllib.parse.urlencode({
        'fx': code,
        'r': region,
        'embed': '1'  # Request only the formatted code HTML
    }).encode('utf-8')
    
    try:
        request = urllib.request.Request(  # nosec B310
            url,
            data=data,
            headers={
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'Markify/1.0'
            }
        )
        
        with urllib.request.urlopen(request, timeout=timeout) as response:  # nosec B310
            html = response.read().decode('utf-8')
            
            # Extract formatted code from HTML response
            formatted = extract_code_from_html(html)
            if formatted:
                return formatted
            
    except urllib.error.URLError:
        # Network error - return original
        pass
    except urllib.error.HTTPError:
        # API error - return original
        pass
    except TimeoutError:
        # Timeout - return original
        pass
    except Exception:  # nosec B110
        # Any other error - return original
        pass
    
    return code


def extract_code_from_html(html: str) -> str:
    """
    Extract formatted DAX code from the HTML response.
    
    The API returns HTML with spans for syntax highlighting.
    We extract just the text content.
    """
    if not html:
        return ""
    
    # First, remove script tags and their content entirely
    text = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
    
    # Remove style tags and their content
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL | re.IGNORECASE)
    
    # Remove HTML comments
    text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
    
    # Remove HTML tags but preserve line breaks
    # Replace <br> and </div> with newlines
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'</div>', '\n', text)
    text = re.sub(r'</p>', '\n', text)
    
    # Remove all remaining HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    
    # Decode HTML entities
    text = text.replace('&nbsp;', ' ')
    text = text.replace('&lt;', '<')
    text = text.replace('&gt;', '>')
    text = text.replace('&amp;', '&')
    text = text.replace('&quot;', '"')
    text = text.replace('&#39;', "'")
    
    # Clean up whitespace
    lines = [line.rstrip() for line in text.split('\n')]
    
    # Remove empty lines at start and end
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    
    # Filter out any remaining JSON-like lines (safety check)
    filtered_lines = []
    for line in lines:
        stripped = line.strip()
        # Skip lines that look like JSON objects/arrays
        if stripped.startswith('{"') and stripped.endswith('}'):
            continue
        if stripped.startswith('[{"') and stripped.endswith('}]'):
            continue
        # Skip branding line
        if 'DAX Formatter by SQLBI' in stripped:
            continue
        filtered_lines.append(line)
    
    # Remove empty lines at start and end again after filtering
    while filtered_lines and not filtered_lines[0].strip():
        filtered_lines.pop(0)
    while filtered_lines and not filtered_lines[-1].strip():
        filtered_lines.pop()
    
    return '\n'.join(filtered_lines)


def is_dax_formatter_available(timeout: int = 3) -> bool:
    """
    Check if the DAX Formatter API is accessible.
    
    Args:
        timeout: Connection timeout in seconds
    
    Returns:
        True if API is reachable, False otherwise
    """
    try:
        request = urllib.request.Request(  # nosec B310
            "https://www.daxformatter.com/",
            headers={'User-Agent': 'Markify/1.0'}
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:  # nosec B310
            return response.status == 200
    except Exception:  # nosec B110
        return False
