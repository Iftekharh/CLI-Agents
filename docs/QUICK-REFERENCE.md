# 🚀 MCP Quick Reference Card

## In Any New GitHub Copilot CLI Session

### Just Say:
```
"Connect to woodgrove environment"
```

### Or Run:
```powershell
cd C:\App\loop
.\mcp-env.ps1 use woodgrove
```

---

## Common Commands

| Command | What It Does |
|---------|-------------|
| `.\mcp-env.ps1 list` | Show all available environments |
| `.\mcp-env.ps1 use woodgrove` | Switch to woodgrove |
| `.\mcp-env.ps1 current` | Show current environment |
| `.\mcp-env.ps1 refresh` | Refresh token |
| `.\mcp-env.ps1 add` | Add new environment |

---

## Your Pre-Configured Environments

### woodgrove (Current)
- **Tenant:** 536279f6-15cc-45f2-be2d-61e352b51eef
- **Resource:** 4500ebfb-89b6-4b14-a480-7f749797bfcd
- **Server:** https://sentinel.microsoft.com/mcp/data-exploration

---

## Troubleshooting

### "Please run az login"
```powershell
az login --tenant 536279f6-15cc-45f2-be2d-61e352b51eef
```

### Token Expired
```powershell
.\mcp-env.ps1 refresh
```

### Check Token Status
```powershell
.\decode-token.ps1
```

---

## Files Location

All files are in: `C:\App\loop\`

- `mcp-environments.json` - Environment profiles
- `mcp-env.ps1` - Environment manager
- `mcp.json` - Active MCP config (auto-updated)
- `MCP-ENVIRONMENT-SETUP.md` - Full guide

---

## Adding Production/Other Environments

1. Run: `.\mcp-env.ps1 add`
2. Enter: name, tenant ID, resource ID, server URL
3. Use: `.\mcp-env.ps1 use production`

---

**Next Session?** Just say: *"Connect to woodgrove"* and you're ready! 🎉
