#import "SectionLine.h"

#define REGEX @"^(.+):(?\\s*(.+))$"

@interface SectionLine()
@property (nonatomic, strong) NSString *line;
@end

@implementation SectionLine

+ (instancetype)buildWithLine:(NSString *)line {
	NSRange range = [line rangeOfString:@":"];

	if (range.location != NSNotFound) {
		SectionLine *rc = [[SectionLine alloc] init];

		rc.line = line;
		rc.sectionName = [line substringToIndex:range.location];

		if (range.location + 1 < line.length)
			rc.sectionValue = [line substringFromIndex:range.location + 1];

		return rc;
	}

	return nil;
}

- (NSString *)symbolicate {
	return self.line;
}

@end
