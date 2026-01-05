"""
Power Query (M) Formatter API integration.
Formats M code using the powerqueryformatter.com service.
"""

import json
import urllib.error
import urllib.parse
import urllib.request


def format_pq(code: str, line_width: int = 80, timeout: int = 5) -> str:
    """
    Format Power Query M code using powerqueryformatter.com API.

    Args:
        code: Raw M code to format
        line_width: Maximum line width (default 80)
        timeout: Request timeout in seconds

    Returns:
        Formatted M code, or original code if API call fails
    """
    if not code or not code.strip():
        return code

    # API endpoint
    url = "https://m-formatter.azurewebsites.net/api/v2"

    # Prepare JSON payload
    payload = json.dumps({
        "code": code,
        "resultType": "text",
        "lineWidth": line_width
    }).encode('utf-8')

    try:
        request = urllib.request.Request(  # nosec B310
            url,
            data=payload,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Markify/1.0'
            }
        )

        with urllib.request.urlopen(request, timeout=timeout) as response:  # nosec B310
            result_text = response.read().decode('utf-8')

            # The API returns JSON with 'success', 'result', and 'errors' fields
            try:
                result_json = json.loads(result_text)
                if result_json.get('success') and result_json.get('result'):
                    return result_json['result'].strip()
            except json.JSONDecodeError:
                # If not JSON, treat as plain text
                if result_text and result_text.strip():
                    return result_text.strip()

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


def is_pq_formatter_available(timeout: int = 3) -> bool:
    """
    Check if the Power Query Formatter API is accessible.

    Args:
        timeout: Connection timeout in seconds

    Returns:
        True if API is reachable, False otherwise
    """
    try:
        request = urllib.request.Request(  # nosec B310
            "https://m-formatter.azurewebsites.net/api/v2",
            headers={'User-Agent': 'Markify/1.0'}
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:  # nosec B310
            return response.status == 200
    except Exception:  # nosec B110
        return False
