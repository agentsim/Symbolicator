#import "ExceptionTraceLine.h"

// XXX: Improve, enforce starting with '(' ending with ')' last backtrace having no space before final ')'
#define REGEX @"(0x[\\dabcdef]+)"

@interface ExceptionTraceLine()
@property (nonatomic, strong) NSString *origLine;
@property (nonatomic, strong) NSArray *backtrace;
@property (nonatomic, weak) SymbolicationTasksBlackboard *bb;
@end

@implementation ExceptionTraceLine

+ (instancetype)buildWithLine:(NSString *)line andBlackboard:(SymbolicationTasksBlackboard *)bb {
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:REGEX
																		   options:NSRegularExpressionCaseInsensitive
																			 error:nil];

	if (line.length > 0 && [line characterAtIndex:0] == '(' && [line characterAtIndex:line.length - 1] == ')') {
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
		
		if (parts.count > 0) {
			ExceptionTraceLine *rc = [[ExceptionTraceLine alloc] init];

			[parts enumerateObjectsUsingBlock:^(NSString *hexAddr, NSUInteger idx, BOOL *stop) {
				uint64_t addr = strtoll([hexAddr UTF8String], NULL, 16);

				[bb addAddress:addr];
			}];

			rc.origLine = line;
			rc.backtrace = parts;
			rc.bb = bb;
			return rc;
		}
	}

	return nil;
}

- (NSString *)symbolicate {
	BOOL isSymbolicated = NO;
	NSMutableString *result = [[NSMutableString alloc] init];

	for (NSString *addrStr in self.backtrace) {
		uint64_t addr = strtoll([addrStr UTF8String], NULL, 16);
		NSString *symbolicated = [self.bb symbolicatedAddress:addr];

		if (symbolicated != (id)[NSNull null]) {
			[result appendString:symbolicated];
			[result appendString:@"\n"];
			isSymbolicated = YES;
		} else {
			[result appendString:addrStr];
			[result appendString:@"\n"];
		}
	}

	if (!isSymbolicated)
		return self.origLine;

	return result;
}

@end
