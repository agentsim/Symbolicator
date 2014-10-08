#import <Foundation/Foundation.h>
#import "CrashReportLine.h"

@interface BinaryImageLine : NSObject<CrashReportLine, NSCopying>

@property (nonatomic, assign) uint64_t loadAddress;
@property (nonatomic, assign) uint64_t endAddress;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *arch;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *rawUuid;
@property (nonatomic, strong) NSString *path;

+ (instancetype)buildWithLine:(NSString *)line;

@end
