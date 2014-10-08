#import "InformationalLine.h"

@interface InformationalLine()
@property (nonatomic, strong) NSString *line;
@end

@implementation InformationalLine

+ (instancetype)buildWithLine:(NSString *)line {
	InformationalLine *rc = [[self alloc] init];

	rc.line = line;
	return rc;
}

- (NSString *)symbolicate {
	return self.line;
}

@end
