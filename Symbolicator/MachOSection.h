#import <Foundation/Foundation.h>

@interface MachOSection : NSObject

@property (nonatomic, strong) NSMutableData *name;
@property (nonatomic, assign) NSInteger addr;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSInteger align;
@property (nonatomic, assign) NSInteger reloff;
@property (nonatomic, assign) NSInteger flags;

@end
