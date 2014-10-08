#import "StackFrameLine.h"

#define REGEX @"^([\\d]+)\\s*([\\S+]+)\\s+(0x[\\dabcdef]+)\\s+(.*)$"

@interface StackFrameLine()
@property (nonatomic, strong) NSString *origLine;
@property (nonatomic, assign) NSInteger frameNumber;
@property (nonatomic, strong) NSString *binaryName;
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, strong) NSString *symbolName;
@property (nonatomic, weak) SymbolicationTasksBlackboard *bb;
@end

@implementation StackFrameLine

+ (instancetype)buildWithLine:(NSString *)line andBlackboard:(SymbolicationTasksBlackboard *)bb {
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:REGEX
																		   options:NSRegularExpressionCaseInsensitive
																			 error:nil];
	__block NSMutableArray *parts = [NSMutableArray array];

	[regex enumerateMatchesInString:line
							options:0
							  range:NSMakeRange(0, line.length)
						 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
							 for (int group = 1; group <= regex.numberOfCaptureGroups; group++) {
								 NSRange r = [result rangeAtIndex:group];

								 [parts addObject:[line substringWithRange:r]];
							 }
						 }];

	if (parts.count == 4) {
		StackFrameLine *rc = [[self alloc] init];

		rc.origLine = line;
		rc.frameNumber = [parts[0] integerValue];
		rc.binaryName = parts[1];
		rc.address = strtoll([parts[2] UTF8String], NULL, 16);
		rc.symbolName = parts[3];
		rc.bb = bb;
		[bb addAddress:rc.address];
		return rc;
	}

	return nil;
}

- (NSString *)symbolicate {
	NSString *result = [self.bb symbolicatedAddress:self.address];

	if (result == (id)[NSNull null])
		return self.origLine;

	return result;
}

@end
