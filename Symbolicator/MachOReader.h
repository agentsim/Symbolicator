#import <Foundation/Foundation.h>
#import <mach/machine.h>
#import "ThinMachObject.h"

@interface MachOReader : NSObject

@property (nonatomic, readonly) NSInteger totalArchitectures;
@property (nonatomic, readonly) NSArray *allThinObjects;

+ (instancetype)buildWithFile:(NSString *)file;

- (BOOL)hasArch:(NSString *)arch;
- (ThinMachObject *)objectForArch:(NSString *)arch;

@end
