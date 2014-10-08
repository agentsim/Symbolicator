#import <Foundation/Foundation.h>

@interface DwarfReader : NSObject

+ (DwarfReader *)buildWithSections:(NSArray *)sections forPath:(NSString *)path;

- (NSDictionary *)symbolicate:(NSMutableDictionary *)addressToSymbol;

@end
