//
//  SUUpdaterStub.m
//
//  No-op stand-in for Sparkle's SUUpdater in the arm64 build.
//
//  Why this exists: the shipped MainMenu.nib references an SUUpdater object and
//  the "Check for Updates" action.  Without a class by that name, unarchiving
//  the nib raises and the app cannot start.  This class keeps the *existing*
//  Slate sources working byte-for-byte; it performs no network access and never
//  installs an update.
//

#import <Sparkle/SUUpdater.h>

@implementation SUUpdater

static SUUpdater *sharedUpdater = nil;

+ (SUUpdater *)sharedUpdater {
  if (sharedUpdater == nil) {
    sharedUpdater = [[SUUpdater alloc] init];
  }
  return sharedUpdater;
}

+ (SUUpdater *)updaterForBundle:(NSBundle *)bundle {
  return [SUUpdater sharedUpdater];
}

- (id)init {
  self = [super init];
  if (self) {
    _automaticallyChecksForUpdates = NO;
    _automaticallyDownloadsUpdates = NO;
    _updateCheckInterval = 0;
  }
  return self;
}

- (void)checkForUpdates:(id)sender {
  NSLog(@"SUUpdater stub: update checking is disabled in this build.");
}

// Tolerate any other key the nib may bind (e.g. via NSUserDefaultsController)
// instead of raising NSUnknownKeyException during nib load.
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
  NSLog(@"SUUpdater stub: ignoring binding for undefined key %@", key);
}

- (id)valueForUndefinedKey:(NSString *)key {
  return nil;
}

@end
