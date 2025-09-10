# Copilot Instructions for CustomChatColors SourcePawn Plugin

## Repository Overview
This repository contains the **CustomChatColors** SourcePawn plugin for SourceMod, a powerful chat customization system for Source engine game servers. The plugin provides comprehensive chat color management, custom tags, chat text replacement, all-chat functionality, and chat ignoring features.

### Key Features
- **Custom Chat Colors**: Per-user name, tag, and chat text coloring
- **Tag System**: Hierarchical tag system with admin/VIP support
- **Chat Replacement**: Configurable text triggers (like `:lenny:` → `( ͡° ͜ʖ ͡°)`)
- **All-Chat**: Cross-team communication functionality
- **Chat Ignoring**: Player-specific chat filtering
- **Database Storage**: Persistent user preferences via SQL
- **Native API**: Extensive API for other plugins via `ccc.inc`

## Technical Environment & Dependencies

### Core Requirements
- **Language**: SourcePawn
- **Platform**: SourceMod 1.12+ (minimum supported version)
- **Compiler**: Latest SourcePawn compiler (spcomp)
- **Database**: MySQL/SQLite support with async operations

### Dependencies (via sourceknight.yaml)
- **sourcemod**: Core SourceMod framework (1.11.0-git6934+)
- **multicolors**: Advanced color handling (`#include <multicolors>`)
- **SelfMute**: Self-muting functionality (optional)
- **sourcebans-pp**: SourceBans++ integration (optional)
- **DynamicChannels**: Multi-channel chat support (optional)

### Build System
- **Tool**: SourceKnight build system (`sourceknight.yaml`)
- **CI**: GitHub Actions using `maxime1907/action-sourceknight@v1`
- **Output**: Compiled `.smx` files in `/addons/sourcemod/plugins`

## File Structure & Architecture

```
addons/sourcemod/
├── scripting/
│   ├── CustomChatColors.sp      # Main plugin (4746 lines)
│   └── include/
│       └── ccc.inc              # Native API definitions
├── configs/
│   ├── custom-chatcolorsreplace.cfg       # Chat replacement config
│   └── custom-chatcolorsreplace-csgo.cfg  # CSGO-specific replacements
└── translations/
    └── allchat.phrases.txt      # Translation phrases
```

### Core Components
1. **CustomChatColors.sp**: Main plugin logic, event handling, database operations
2. **ccc.inc**: Native function definitions and API for external plugins
3. **Configuration Files**: Chat replacement triggers and game-specific settings
4. **Translation Files**: Localized text for user-facing messages

## Code Style & Standards

### SourcePawn Conventions
```sourcepawn
#pragma semicolon 1           // Mandatory semicolons
#pragma newdecls required     // New declaration syntax

// Variable naming
int g_iGlobalVariable;        // Global int with g_ prefix and Hungarian notation
char g_sGlobalString[64];     // Global string with g_s prefix
bool g_bGlobalBoolean;        // Global boolean with g_b prefix

// Function naming
void MyFunctionName()         // PascalCase for functions
{
    int localVariable;        // camelCase for local variables
    char localString[32];     // camelCase for local variables
}
```

### Database Patterns
```sourcepawn
// ALWAYS use async SQL operations
DataPack pack = new DataPack();
pack.WriteCell(client);
g_hDatabase.Query(SQL_Callback, "SELECT * FROM table WHERE steamid = ?", pack, steamid);

// Use prepared statements to prevent SQL injection
char query[256];
g_hDatabase.Format(query, sizeof(query), "UPDATE table SET value = ? WHERE steamid = ?");
g_hDatabase.Query(callback, query, pack, value, steamid);
```

### Memory Management
```sourcepawn
// Use delete without null checks (modern SourcePawn)
delete g_hArray;              // No need to check for null first
g_hArray = new ArrayList();   // Recreate instead of .Clear()

// StringMap/ArrayList best practices
delete g_hStringMap;          // Never use .Clear() - creates memory leaks
g_hStringMap = new StringMap();
```

## Development Workflow

### 1. Understanding the Codebase
- **Main Plugin**: `CustomChatColors.sp` contains all core functionality
- **Database Schema**: Player preferences stored with async SQL patterns
- **Event Flow**: OnClientPostAdminCheck → LoadClientData → ApplyColors/Tags
- **Command Structure**: Admin commands (`sm_ccc*`) and user commands (`sm_tag*`)

### 2. Making Changes

#### For Color/Tag System Changes:
1. Understand existing client data structures (`g_sClientTag`, `g_sClientTagColor`, etc.)
2. Check database schema interactions (async SQL callbacks)
3. Test with both admin and regular users
4. Verify color parsing and MultiColors integration

#### For Database Changes:
1. All SQL operations MUST be asynchronous
2. Use proper error handling in SQL callbacks
3. Escape strings properly to prevent SQL injection
4. Test with both MySQL and SQLite

#### For New Commands:
1. Register in `OnPluginStart()`
2. Add proper permission checks (admin flags)
3. Include user-friendly error messages
4. Add translation support if user-facing

### 3. Build Process
```bash
# The build uses SourceKnight (GitHub Actions handles this)
# Local building requires SourceKnight installation
sourceknight build
```

### 4. Testing Approach
- **Unit Testing**: Test individual functions with various input types
- **Integration Testing**: Test with live SourceMod server
- **Database Testing**: Verify async SQL operations and error handling
- **Performance Testing**: Check impact on server tick rate
- **Compatibility Testing**: Test with dependency plugins loaded/unloaded

## Common Development Tasks

### Adding New Chat Replacement Triggers
1. Edit `addons/sourcemod/configs/custom-chatcolorsreplace.cfg`
2. Use format: `":trigger:" "replacement text with {colors}"`
3. Test with `sm_cccimportreplacefile` command
4. Consider game-specific configs for different Source games

### Adding New Color Types
1. Update `CCC_ColorType` enum in `ccc.inc`
2. Add storage variables in main plugin
3. Update database schema and SQL operations
4. Add native functions for external plugin access
5. Update color application logic in chat processing

### Database Schema Changes
1. Create migration queries for existing installations
2. Update all related SQL operations (SELECT, INSERT, UPDATE, DELETE)
3. Handle backwards compatibility
4. Test with both MySQL and SQLite databases

### Performance Optimization
```sourcepawn
// Cache frequently accessed data
if (g_iClientLastCheck[client] == GetTime()) {
    return g_sCachedResult[client];
}

// Minimize string operations in frequent functions
// Use StringMap for O(1) lookups instead of loops
// Avoid unnecessary database queries
```

## Architecture Patterns

### Event-Driven Design
- Hook SourceMod events (`player_say`, `OnClientPostAdminCheck`)
- Use forwards for plugin communication (`CCC_OnUserConfigLoaded`)
- Implement proper cleanup in `OnClientDisconnect`

### Database Abstraction
- Support both MySQL and SQLite
- Use async operations with proper callback handling
- Implement retry logic for failed operations

### Configuration Management
- Support runtime config reloading (`sm_reloadccc`)
- Validate configuration on load
- Provide admin tools for config management

## Integration Points

### External Plugin API (ccc.inc)
```sourcepawn
// Other plugins can use these natives
native bool CCC_GetColor(char key[32], char[] color, int size);
native int CCC_SetColor(int client, CCC_ColorType type, int color, bool alpha);
native void CCC_SetTag(int client, const char[] tag);

// Forward notifications
forward void CCC_OnUserConfigLoaded(int client);
forward Action CCC_OnChatMessage(int client, int author, const char[] message);
```

### Dependency Integration
- **MultiColors**: Color parsing and application
- **SelfMute**: Respect muted players in chat processing
- **SourceBans**: Integration with ban system
- **DynamicChannels**: Multi-channel chat support

## Debugging & Troubleshooting

### Common Issues
1. **Database Connection**: Check `g_DatabaseState` and connection retry logic
2. **Color Not Applying**: Verify MultiColors dependency and color format
3. **Commands Not Working**: Check admin flags and plugin load order
4. **Memory Leaks**: Ensure proper `delete` usage, avoid `.Clear()` on containers

### Debug Techniques
```sourcepawn
// Use LogError for debugging
LogError("CCC Debug: Client %d tag: %s", client, g_sClientTag[client]);

// Check plugin load state
if (!IsClientInGame(client)) {
    LogError("Client %d not in game", client);
    return;
}
```

## Security Considerations

### SQL Injection Prevention
```sourcepawn
// ALWAYS use parameterized queries
char query[256];
g_hDatabase.Format(query, sizeof(query), "SELECT * FROM ccc WHERE steamid = ?");
g_hDatabase.Query(callback, query, pack, steamid);

// NEVER concatenate user input directly
// BAD: Format(query, sizeof(query), "SELECT * FROM ccc WHERE name = '%s'", userName);
```

### Input Validation
```sourcepawn
// Validate chat input length and content
if (strlen(input) > MAX_CHAT_LENGTH) {
    ReplyToCommand(client, "Input too long");
    return Plugin_Handled;
}

// Sanitize color inputs
if (!IsValidColor(colorInput)) {
    ReplyToCommand(client, "Invalid color format");
    return Plugin_Handled;
}
```

## Performance Guidelines

### Optimization Priorities
1. **Chat Processing**: Minimize operations in frequently called chat hooks
2. **Database Queries**: Use connection pooling and query optimization
3. **String Operations**: Cache results, use efficient string handling
4. **Memory Usage**: Proper cleanup, avoid memory leaks

### Performance Monitoring
- Monitor server tick rate impact during heavy chat periods
- Profile database operation times
- Check memory usage growth over time
- Use SourceMod's built-in profiler for function timing

## Version Management

### Versioning Pattern
- Uses semantic versioning in `ccc.inc`: `#define CCC_VERSION "7.4.19"`
- Update version in three places: `CCC_V_MAJOR`, `CCC_V_MINOR`, `CCC_V_PATCH`
- Tag releases in Git to match version numbers

### Compatibility
- Maintain backwards compatibility for database schema
- Support minimum SourceMod version 1.12+
- Test with multiple Source engine games (CS:GO, TF2, etc.)

## Final Notes

This plugin is mature and complex with extensive database integration, multi-game support, and external plugin compatibility. When making changes:

1. **Always test thoroughly** with a live server environment
2. **Maintain backwards compatibility** especially for database and API
3. **Follow async patterns** for all database operations
4. **Use existing code patterns** rather than introducing new paradigms
5. **Consider performance impact** on server tick rate
6. **Document any new natives or forwards** for external plugins

The codebase follows modern SourcePawn best practices and serves as a good example of professional SourceMod plugin development.