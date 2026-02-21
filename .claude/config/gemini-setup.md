# Gemini CLI Setup

## Prerequisites

- Google Cloud account with Gemini API access
- `gcloud` CLI installed and authenticated

## Installation

### macOS / Linux

```bash
# Install gcloud CLI (if not present)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate
gcloud auth login
gcloud auth application-default login

# Enable Gemini API
gcloud services enable generativelanguage.googleapis.com
```

### Windows

```powershell
# Install via winget
winget install Google.CloudSDK

# Authenticate
gcloud auth login
gcloud auth application-default login

# Enable Gemini API
gcloud services enable generativelanguage.googleapis.com
```

## API Key Setup

```bash
# Option 1: Environment variable
export GEMINI_API_KEY="your-api-key"

# Option 2: Store in orchestrator vault config
# See config/orchestrator.yaml vault section
```

## Verify Setup

```bash
# Test API access
gemini --version

# Test model availability
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" \
  | jq '.models[].name'
```

## Available Models

| Model              | Context | Use For                               |
| ------------------ | ------- | ------------------------------------- |
| `gemini-2.5-pro`   | 1M      | Large codebase analysis, doc research |
| `gemini-2.5-flash` | 1M      | Fast analysis, summarization          |
| `gemini-2.0-flash` | 1M      | Lightweight tasks                     |

## Orchestrator Integration

Gemini is configured as a provider in `config/orchestrator.yaml`:

```yaml
gemini:
  cli_path: "$CLAUDE_HOME/scripts/gemini-run.sh"
  auth_check: "gemini --version"
  privacy_level: public
  cost_tier: premium
```

## Constraints

- **Research-only**: summarization, analysis, large-context reading
- **NOT for code generation** or task execution (use Copilot/Claude)
- 1M context window is its primary advantage
- Data is sent to Google Cloud (not safe for sensitive/PII data)

## Troubleshooting

| Issue               | Fix                                                        |
| ------------------- | ---------------------------------------------------------- |
| Auth fails          | `gcloud auth application-default login`                    |
| API not enabled     | `gcloud services enable generativelanguage.googleapis.com` |
| Rate limit          | Check quota at console.cloud.google.com                    |
| Model not available | Verify region supports the model                           |
