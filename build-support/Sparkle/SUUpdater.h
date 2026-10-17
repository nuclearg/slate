//
//  SUUpdater.h  (compatibility shim — NOT Sparkle)
//
//  Slate's MainMenu.nib contains a custom object of class "SUUpdater" whose
//  "automaticallyChecksForUpdates" property is bound in Interface Builder, and
//  SlateAppDelegate's -relaunch looks up the "relaunch" helper through
//  +[NSBundle bundleForClass:[SUUpdater class]].
//
//  The arm64 build does not link Sparkle.  This header + SUUpdaterStub.m keep
//  both of those code paths working unchanged (the class still exists at
//  runtime; update checking is simply a no-op), so the nib still unarchives
//  and -relaunch still finds the helper shipped in Slate.app/Contents/Resources.
//

#import <Foundation/Foundation.h>

@interface SUUpdater : NSObject

+ (SUUpdater *)sharedUpdater;
+ (SUUpdater *)updaterForBundle:(NSBundle *)bundle;

@property (assign) id delegate;
@property (assign) BOOL automaticallyChecksForUpdates;
@property (assign) BOOL automaticallyDownloadsUpdates;
@property (assign) NSTimeInterval updateCheckInterval;
@property (retain) NSURL *feedURL;

- (IBAction)checkForUpdates:(id)sender;

@end
