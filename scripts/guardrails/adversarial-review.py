#!/usr/bin/env python3
"""
🛡️ Guardrail Architect — Adversarial Review Script
Runs a separate Claude session as a code critic.
Requires: ANTHROPIC_API_KEY environment variable
Install: pip install anthropic
Usage: python adversarial-review.py [--diff-cmd "git diff origin/main...HEAD"]
"""

import subprocess
import sys
import os
import json
import argparse

def get_diff(diff_cmd: str = "git diff") -> str:
    """Get the code diff to review."""
    result = subprocess.run(diff_cmd.split(), capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running '{diff_cmd}': {result.stderr}")
        sys.exit(1)
    return result.stdout

def get_claude_md() -> str:
    """Load CLAUDE.md for architecture context if present."""
    for path in ["CLAUDE.md", "../CLAUDE.md"]:
        if os.path.exists(path):
            with open(path) as f:
                return f.read()
    return ""

def run_review(diff: str, context: str) -> dict:
    """Send diff to Claude for adversarial review."""
    try:
        import anthropic
    except ImportError:
        print("Install the Anthropic SDK: pip install anthropic")
        sys.exit(1)

    client = anthropic.Anthropic()

    system_prompt = """You are an adversarial code reviewer. Your job is to FIND PROBLEMS, not approve code.

Review the diff against these criteria:
1. TYPE SAFETY: Missing annotations, Any usage, wrong types, hallucinated methods
2. ARCHITECTURE: Layer violations, circular deps, boundary violations
3. SECURITY: Hardcoded secrets, injection vectors, unsafe deserialization
4. LOGIC: Off-by-one, timezone-naive datetimes, float equality for money, missing error handling
5. TESTING: New functions without tests, meaningless assertions
6. TRADING/FINANCE (if applicable): Position sizing without limits, float for money, unbounded loss

Respond in this exact JSON format:
{
  "verdict": "APPROVED" | "REJECTED" | "NEEDS_CHANGES",
  "confidence": "high" | "medium" | "low",
  "issues": [
    {
      "severity": "critical" | "high" | "medium" | "low",
      "file": "path/to/file.py",
      "line": "approximate line or range",
      "description": "what's wrong",
      "fix": "how to fix it"
    }
  ],
  "positives": ["what looks good"],
  "summary": "1-2 sentence overall assessment"
}

Be thorough. Be critical. Only APPROVE if you genuinely cannot find issues."""

    user_msg = f"Review this diff:\n\n```diff\n{diff[:50000]}\n```"
    if context:
        user_msg += f"\n\nArchitecture rules (CLAUDE.md):\n```\n{context[:5000]}\n```"

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=system_prompt,
        messages=[{"role": "user", "content": user_msg}]
    )

    text = response.content[0].text

    # Extract JSON from response
    try:
        # Handle markdown code blocks
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        return json.loads(text)
    except (json.JSONDecodeError, IndexError):
        return {
            "verdict": "NEEDS_CHANGES",
            "confidence": "low",
            "issues": [{"severity": "medium", "file": "N/A", "line": "N/A",
                        "description": "Could not parse review output", "fix": "Run manually"}],
            "positives": [],
            "summary": text[:500]
        }

def format_report(review: dict) -> str:
    """Format the review as a readable report."""
    severity_icons = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🔵"}
    verdict_icons = {"APPROVED": "✅", "REJECTED": "❌", "NEEDS_CHANGES": "⚠️"}

    lines = [
        "## 🛡️ Adversarial Review",
        "",
        f"**Verdict**: {verdict_icons.get(review['verdict'], '❓')} {review['verdict']}",
        f"**Confidence**: {review.get('confidence', 'unknown')}",
        "",
    ]

    issues = review.get("issues", [])
    if issues:
        lines.append("### Issues Found")
        lines.append("")
        for issue in sorted(issues, key=lambda x: ["critical", "high", "medium", "low"].index(x.get("severity", "low"))):
            sev = issue.get("severity", "medium")
            icon = severity_icons.get(sev, "⚪")
            lines.append(f"{icon} **{sev.upper()}** — {issue.get('file', 'N/A')}:{issue.get('line', '?')}")
            lines.append(f"   {issue.get('description', '')}")
            if issue.get("fix"):
                lines.append(f"   Fix: {issue['fix']}")
            lines.append("")
    else:
        lines.append("### No Issues Found")
        lines.append("")

    positives = review.get("positives", [])
    if positives:
        lines.append("### What Looks Good")
        for p in positives:
            lines.append(f"- {p}")
        lines.append("")

    lines.append("### Summary")
    lines.append(review.get("summary", "No summary available."))

    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Adversarial code review via Claude")
    parser.add_argument("--diff-cmd", default="git diff", help="Command to get diff")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Set ANTHROPIC_API_KEY environment variable")
        sys.exit(1)

    diff = get_diff(args.diff_cmd)
    if not diff.strip():
        print("No changes to review.")
        sys.exit(0)

    print("🛡️ Running adversarial review...")
    context = get_claude_md()
    review = run_review(diff, context)

    if args.json:
        print(json.dumps(review, indent=2))
    else:
        print(format_report(review))

    # Exit code based on verdict
    if review.get("verdict") == "REJECTED":
        sys.exit(1)
    elif review.get("verdict") == "NEEDS_CHANGES":
        sys.exit(2)
    sys.exit(0)

if __name__ == "__main__":
    main()
