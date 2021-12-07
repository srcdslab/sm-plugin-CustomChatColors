# CustomChatColors

Processes chat and provides colors, custom tags and allchat

## Commands

### Admin
- sm_reloadccc - "Reloads Custom Chat Colors config file"

### Public
- sm_tag - "Changes your custom tag"
- sm_tagcolor - "Changes the color of your custom tag"
- sm_namecolor - "Changes the color of your name"
- sm_chatcolor - "Changes the color of your chat text"
- sm_toggletag - "Toggles whether or not your tag and colors show in the chat"

## Configuration

### Admin Flags
```sm_cccaddtag Admins 1 Admins b "[ADMIN] " "darkred" "green" "darkblue"```

### VIP Flags
```sm_cccaddtag VIP 1 VIP o "[VIP] " "pink" "teamcolor" "default"```

### Replace triggers
```sm_cccimportreplacefile custom-chatcolorsreplace.cfg```
