#import "AppDelegate.h"
#import "CrashReportParser.h"
#import "libdwarf.h"
#import "MachOReader.h"

@interface AppDelegate ()
@property (nonatomic, strong) CrashReportParser *hack;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
	CrashReportParser *parser = [CrashReportParser buildForFile:filename];

	self.hack = parser;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[parser parse];
		//[parser write];
	});
	return parser != nil;
}

@end
