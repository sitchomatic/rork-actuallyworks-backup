# Reconnect the More Menu & Dashboard to App Navigation

## Problem

The "More" menu containing Automation Tools, AI Custom Tools, Account Tools, Debug tools, Data management, and Advanced Settings is completely disconnected — no screen in the app navigates to it.

## What Gets Fixed

### 1. Unified Sessions — Add "More" Access

- Add a **"More"** option to the Unified Sessions toolbar menu (the ··· button top-left)
- Tapping it opens the full More menu as a sheet with all tools: AI Custom Tools, Automation Tools, URLs & Endpoint, Advanced Settings, Account Tools, Data, and Debug sections
- Everything inside the More menu (Flow Recorder, Saved Flows, Blacklist, Export, Disabled Accounts, Replay Debugger, etc.) becomes reachable again

### 2. PPSR Mode — Add "More" Access

- Add a **"More"** toolbar button to the PPSR Dashboard tab
- Opens the same full More menu so PPSR users can also access Automation Tools, Account Tools, Debug, etc.

### 3. Ensure All Links Inside More Menu Work

- Verify every NavigationLink inside the More menu (Automation Tools → Flow Recorder, Saved Flows, Login Button Detection; Account Tools → Check Disabled, Temp Disabled; Data → Blacklist, Export; Debug → Screenshots, Replay Debugger, Tap Heatmap) navigates correctly when presented as a sheet
- Wrap the More menu content in its own NavigationStack so push navigation works inside the sheet

## What Stays Unchanged

- Main Menu grid layout (Unified Sessions, Dual Find, Test & Debug, PPSR, Settings & Testing, Connection Mode)
- The floating "MENU" button that returns to the main menu
- Settings & Testing view (accessible from both main menu and More menu)
- All existing toolbar items in Unified Sessions and PPSR

