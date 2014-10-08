#import <Foundation/Foundation.h>

@interface ThinMachObject : NSObject

@property (nonatomic, strong) NSString *arch;
@property (nonatomic, strong) NSString *uuid;

+ (instancetype)buildWithHandle:(NSFileHandle *)fH size:(NSInteger)size forPath:(NSString *)path;

- (void)parse;
- (NSDictionary *)symbolicate:(NSArray *)addresses;

@end
