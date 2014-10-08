#import <Foundation/Foundation.h>
#import "CrashReportLine.h"

@interface SectionLine : NSObject<CrashReportLine>

@property (nonatomic, strong) NSString *sectionName;
@property (nonatomic, strong) NSString *sectionValue;

+ (instancetype)buildWithLine:(NSString *)line;

@end
