#import <Foundation/Foundation.h>
#import "CrashReportLine.h"
#import "SymbolicationTasksBlackboard.h"

@interface StackFrameLine : NSObject<CrashReportLine>

+ (instancetype)buildWithLine:(NSString *)line andBlackboard:(SymbolicationTasksBlackboard *)bb;

@end
