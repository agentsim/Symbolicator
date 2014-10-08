#import <Foundation/Foundation.h>

@interface CrashReportParser : NSObject

+ (instancetype)buildForFile:(NSString *)file;

- (void)parse;
- (void)write;

@end
