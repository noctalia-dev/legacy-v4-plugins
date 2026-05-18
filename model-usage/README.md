# Model Usage Bar Widget

This plugin adds a compact usage capsule to the Noctalia bar and a detail panel for provider stats.

## How it works

- `Main.qml` wires provider modules and decides which provider is active.
- `BarWidget.qml` shows one metric (`prompts`, `tokens`, or `usage`) for the active provider.
- `Panel.qml` shows provider details like rate-limit usage, today stats, and recent activity.
- `Settings.qml` controls enabled providers, API keys, and refresh behavior.

Current providers:

- `Claude` reads local Claude auth/session files, refreshes OAuth tokens when needed.
- `Codex` reads local `~/.codex` history/session/auth files. Displays both the primary (5-hour) and secondary (weekly) rate-limit windows.
- `OpenRouter` uses the OpenRouter key/activity APIs.
- `Zen` uses the OpenCode Zen API for key validation and model discovery. Zen usage percent is not currently exposed by a documented endpoint, so it reports a neutral usage value.
- `MiniMax` fetches the MiniMax coding/token plan quota endpoint. Shows the 5-hour rolling window as the primary limit and the weekly window as the secondary limit when weekly data is available. Does not track local prompt/token history.

## Usage

1. Open the plugin settings.
2. Enable the providers you want.
3. Add API keys for API-based providers (`OpenRouter`, `Zen`, `MiniMax`) or use environment variables.
4. Choose the bar metric and refresh interval.
5. Apply settings and open the panel to verify provider status.

## API key options

- OpenRouter: `OPENROUTER_API_KEY` or settings field.
- Zen: `OPENCODE_ZEN_API_KEY`, `OPENCODE_API_KEY`, `ZEN_API_KEY`, or settings field.
- MiniMax: `MINIMAX_API_KEY`, `MINIMAX_TOKEN_PLAN_API_KEY`, `MINIMAX_CODING_PLAN_API_KEY`, or settings field. MiniMax also checks `ANTHROPIC_AUTH_TOKEN` when `ANTHROPIC_BASE_URL` contains "minimax", and `OPENAI_API_KEY` when `OPENAI_BASE_URL` or `OPENAI_API_BASE` contains "minimax".

## MiniMax region

MiniMax defaults to the international endpoint (`https://api.minimax.io/v1`). Set region to "China" in settings to use the China endpoint (`https://api.minimaxi.com/v1`). A custom `apiBaseUrl` in settings overrides both defaults.
