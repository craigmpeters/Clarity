# CloudKit Sync Setup Instructions for Clarity

## What's Been Implemented

✅ **SwiftData Models Updated for CloudKit:**
- Added `@CloudKitSync` to `ToDoTask`, `Category`, and `GlobalTargetSettings`
- All models now support automatic CloudKit synchronization

✅ **CloudKit Configuration:**
- Updated `ModelConfiguration` with CloudKit database: `"iCloud.me.craigpeters.clarity"`
- Using private CloudKit database for user data

✅ **CloudKit Sync Manager:**
- `CloudKitSyncManager` handles sync status, account availability, and manual sync
- Monitors CloudKit account changes
- Provides user-friendly status messages

✅ **UI Integration:**
- New `CloudKitSyncSettingsView` shows sync status in Settings
- Manual sync button when needed
- Error handling and account status display
- Updated `SettingsView` with CloudKit section

## Required Xcode Project Configuration

### 1. Enable CloudKit Capability
1. In Xcode, select your project target
2. Go to "Signing & Capabilities" tab  
3. Click the "+" button and add "CloudKit"
4. Select or create container: `iCloud.me.craigpeters.clarity`

### 2. Enable iCloud Capability
1. Also add "iCloud" capability if not present
2. Enable "CloudKit" service within iCloud capability

### 3. Update App Identifier
Make sure your app's bundle identifier matches the CloudKit container:
- Container ID: `iCloud.me.craigpeters.clarity`
- App Bundle ID: `me.craigpeters.clarity` (or similar)

### 4. CloudKit Dashboard Setup
1. Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard/)
2. Select your container `iCloud.me.craigpeters.clarity`
3. The schema will be automatically created when you first run the app
4. You can monitor sync activity and data in the dashboard

## How It Works

### Automatic Sync
- SwiftData automatically syncs with CloudKit when:
  - Data is saved to the model context
  - App launches and connects to iCloud
  - Device comes online after being offline

### Manual Sync
- Users can tap "Sync Now" in Settings to force synchronization
- Useful when troubleshooting or ensuring latest data

### Conflict Resolution
- SwiftData handles most conflicts automatically
- Uses CloudKit's last-writer-wins strategy
- More complex conflict resolution can be added if needed

### Offline Support
- App works fully offline
- Changes are queued and sync when connection is restored
- Users see sync status and can retry failed syncs

## User Experience

### First Launch
1. App requests iCloud account status
2. If signed in, sync begins automatically
3. If not signed in, Settings shows helpful message

### Sync Status
- Green checkmark: Successfully synced
- Blue spinner: Currently syncing  
- Red warning: Sync failed with error
- Orange warning: iCloud account unavailable

### Cross-Device Sync
- Tasks, categories, and settings sync across all devices
- Changes appear within seconds on other devices
- Pomodoro sessions remain local (by design)

## Testing

### Test Scenarios
1. **Basic Sync**: Create task on device A, verify it appears on device B
2. **Offline**: Disconnect device, make changes, reconnect and verify sync
3. **Account Issues**: Sign out of iCloud, verify error handling
4. **Conflict Resolution**: Modify same task on two devices simultaneously

### Development Testing
- Use simulator with different iCloud accounts
- Test with real devices for best results
- Monitor CloudKit Console for sync activity

## Troubleshooting

### Common Issues
1. **"Account Not Available"**: User needs to sign in to iCloud in Settings
2. **"Sync Failed"**: Network issues or CloudKit service problems
3. **Missing Data**: Check CloudKit Console for schema issues

### Debug Steps
1. Check Xcode console for CloudKit error messages
2. Verify capabilities are properly configured
3. Ensure app is signed with correct team/certificate
4. Test with fresh CloudKit development database

## Next Steps (Optional Enhancements)

### Advanced Features to Consider
- [ ] Conflict resolution UI for complex conflicts
- [ ] Selective sync (choose which data to sync)
- [ ] Family sharing support
- [ ] CloudKit public database for shared features
- [ ] Sync progress indicators for large datasets
- [ ] Export/import for data portability

### Performance Optimizations
- [ ] Batch sync operations
- [ ] Incremental sync for large datasets  
- [ ] Background sync scheduling
- [ ] Sync prioritization (critical data first)

---

**Note**: Make sure to test thoroughly with different iCloud accounts and network conditions before releasing to users.