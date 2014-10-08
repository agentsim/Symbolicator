#import <Foundation/Foundation.h>
#import "CrashReportLine.h"

@interface InformationalLine : NSObject<CrashReportLine>

+ (instancetype)buildWithLine:(NSString *)line;

@end
