#import <Foundation/Foundation.h>

@interface MachOSegment : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger cmd;
@property (nonatomic, assign) NSInteger cmdSize;
@property (nonatomic, assign) NSInteger vmaddr;
@property (nonatomic, assign) NSInteger vmsize;
@property (nonatomic, assign) NSInteger fileoff;
@property (nonatomic, assign) NSInteger filesize;
@property (nonatomic, assign) NSInteger nsects;
@property (nonatomic, assign) NSInteger flags;

@end
