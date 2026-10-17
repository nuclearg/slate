//
//  relaunch.m
//
//  Replacement for the `relaunch` helper that ships inside Sparkle.framework.
//  SlateAppDelegate -relaunch copies this tool out of the app bundle, runs it
//  with (appPath, pid), and quits.  The tool waits for the old instance to go
//  away and then reopens the bundle — same contract as Sparkle's helper, which
//  is x86_64-only and therefore cannot ship in the arm64 build.
//

#import <Cocoa/Cocoa.h>
#import <signal.h>
#import <errno.h>
#import <unistd.h>

int main(int argc, char *argv[]) {
  @autoreleasepool {
    if (argc < 3) {
      fprintf(stderr, "usage: %s <app path> <pid>\n", argv[0]);
      return 2;
    }

    NSString *path = [NSString stringWithUTF8String:argv[1]];
    pid_t parentPid = (pid_t)atoi(argv[2]);

    if (path == nil) {
      fprintf(stderr, "relaunch: invalid app path\n");
      return 2;
    }

    // Wait for the process that launched us to terminate, so the new instance
    // doesn't race the old one for the same bundle identity.
    if (parentPid > 0) {
      for (;;) {
        errno = 0;
        if (kill(parentPid, 0) != 0 && errno == ESRCH) { break; }
        usleep(100000);
      }
    }

    if (![[NSWorkspace sharedWorkspace] openFile:path]) {
      fprintf(stderr, "relaunch: could not open %s\n", [path UTF8String]);
      return 1;
    }
  }
  return 0;
}
