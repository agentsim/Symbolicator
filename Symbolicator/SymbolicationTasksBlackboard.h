#import <Foundation/Foundation.h>
#import "BinaryImageLine.h"

@interface SymbolicationTasksBlackboard : NSObject

+ (instancetype)build;

- (void)addAddress:(uint64_t)address;
- (NSString *)symbolicatedAddress:(uint64_t)address;
- (void)symbolicateWithPaths:(NSArray *)paths binaryInfo:(NSArray *)binaryLines;

@end
