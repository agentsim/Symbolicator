#import <Foundation/Foundation.h>
#import "MachOSegment.h"

@interface MachONList : NSObject

@property (nonatomic, assign) NSInteger idx;
@property (nonatomic, assign) NSInteger section;
@property (nonatomic, assign) NSInteger value;
@property (nonatomic, strong) NSString *symbol;

// Useful property
@property (nonatomic, strong) MachOSegment *segment;

@end
