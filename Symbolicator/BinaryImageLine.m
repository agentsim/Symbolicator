#import "BinaryImageLine.h"

/*
             ^\s* (\w+) \s* \- \s* (\w+) \s*     (?# the range base and extent [1,2] )
             (\+)?                               (?# the application may have a + in front of the name [3] )
             (.+)                                (?# bundle name [4] )
             \s+ ('.$architectures.') \s+        (?# the image arch [5] )
             \<?([[:xdigit:]]{32})?\>?           (?# possible UUID [6] )
             \s* (\/.*)\s*$                      (?# first fwdslash to end we hope is path [7] )
*/

#define REGEX @"^\\s*(0x[\\dabcdef]+)\\s*\\-\\s*(0x[\\dabcdef]+)\\s*\\+?(.+)\\s+(.+)\\s+\\<(.+)\\>\\s+(\\/.*)\\s*$" // \\s* \(\\+)? (.+) \\s

@interface BinaryImageLine()
@property (nonatomic, strong) NSString *line;
@end

@implementation BinaryImageLine

#pragma mark -
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	BinaryImageLine *rc = [[[self class] allocWithZone:zone] init];

	rc.loadAddress = self.loadAddress;
	rc.endAddress = self.endAddress;
	rc.name = [self.name copy];
	rc.arch = [self.arch copy];
	rc.uuid = [self.uuid copy];
	rc.rawUuid = [self.rawUuid copy];
	rc.path = [self.path copy];
	return rc;
}

- (NSUInteger)hash {
	return [self.uuid hash];
}

- (BOOL)isEqual:(id)object {
	return [self.uuid isEqual:[object uuid]];
}

#pragma mark -
#pragma mark BinaryImageLine

+ (instancetype)buildWithLine:(NSString *)line {
	NSError *err = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:REGEX
																		   options:NSRegularExpressionCaseInsensitive
																			 error:&err];
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

	if (parts.count == 6) {
		BinaryImageLine *rc = [[BinaryImageLine alloc] init];

		rc.line = line;
		rc.loadAddress = strtoll([parts[0] UTF8String], NULL, 16);
		rc.endAddress = strtoll([parts[1] UTF8String], NULL, 16);
		rc.name = parts[2];
		rc.arch = [parts[3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		rc.rawUuid = parts[4];
		rc.uuid = [rc fixUUID:rc.rawUuid];
		rc.path = parts[5];
		return rc;
	}

	return nil;

}

- (NSString *)symbolicate {
	return self.line;
}

#pragma mark -
#pragma mark BinaryImageLine Private Methods

- (NSString *)fixUUID:(NSString *)uuid {
	if (uuid.length == 32) {
		NSMutableString *rc = [[NSMutableString alloc] init];

		uuid = [uuid uppercaseString];
		[rc appendString:[uuid substringWithRange:NSMakeRange(0, 8)]];
		[rc appendString:@"-"];
		[rc appendString:[uuid substringWithRange:NSMakeRange(8, 4)]];
		[rc appendString:@"-"];
		[rc appendString:[uuid substringWithRange:NSMakeRange(12, 4)]];
		[rc appendString:@"-"];
		[rc appendString:[uuid substringWithRange:NSMakeRange(16, 4)]];
		[rc appendString:@"-"];
		[rc appendString:[uuid substringWithRange:NSMakeRange(20, 12)]];
		return rc;
	} else if (uuid.length == 36) {
		return [uuid uppercaseString];
	}

	return nil;
}

@end
