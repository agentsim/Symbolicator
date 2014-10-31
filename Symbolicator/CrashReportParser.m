#import "CrashReportParser.h"
#import "BinaryImageLine.h"
#import "ExceptionTraceLine.h"
#import "InformationalLine.h"
#import "SectionLine.h"
#import "StackFrameLine.h"
#import "SymbolicationTasksBlackboard.h"

@interface CrashReportParser()
@property (nonatomic, strong) NSString *outFile;
@property (nonatomic, strong) NSArray *lines;
@property (nonatomic, strong) NSMutableArray *parsedLines;
@property (nonatomic, strong) NSMutableArray *queries;
@property (nonatomic, strong) NSMutableArray *binaryImageLines;
@property (nonatomic, strong) NSMutableArray *paths;
@property (nonatomic, strong) NSOperationQueue *opQ;
@property (nonatomic, strong) SymbolicationTasksBlackboard *bb;
@property (nonatomic, strong) id observerHandle;
@end

@implementation CrashReportParser

#pragma mark -
#pragma mark NSObject

- (void)dealloc {
	if (self.observerHandle)
		[[NSNotificationCenter defaultCenter] removeObserver:self.observerHandle];
}

#pragma mark -
#pragma mark CrashReportParser

+ (instancetype)buildForFile:(NSString *)file {
	CrashReportParser *rc = [[self alloc] init];
	NSString *str = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];

	rc.bb = [SymbolicationTasksBlackboard build];
	rc.parsedLines = [NSMutableArray array];
	rc.binaryImageLines = [NSMutableArray array];
	rc.queries = [NSMutableArray array];
	rc.paths = [NSMutableArray array];
	rc.lines = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	rc.outFile = [file stringByAppendingPathExtension:@"symbolicated"];
	rc.opQ = [[NSOperationQueue alloc] init];
	rc.observerHandle = [[NSNotificationCenter defaultCenter] addObserverForName:NSMetadataQueryDidFinishGatheringNotification
																		  object:nil
																		   queue:nil
																	  usingBlock:^(NSNotification *note) {
																		  @synchronized(rc) {
																			  NSMetadataQuery *query = (NSMetadataQuery *)note.object;
																			  
																			  [query enumerateResultsUsingBlock:^(id result, NSUInteger idx, BOOL *stop) {
																				  NSMetadataItem *item = result;
																				  NSString *path = [item valueForKey:NSMetadataItemPathKey];
																				  NSArray *dSyms = [item valueForKey:@"com_apple_xcode_dsym_paths"];

																				  if (dSyms.count > 0) {
																					  for (NSString *sym in dSyms)
																						  [rc.paths addObject:[path stringByAppendingPathComponent:sym]];
																				  }
																			  }];
																			  
																			  [query stopQuery];
																			  [rc.queries removeObject:query];
																			  
																			  if (rc.queries.count == 0) {
																				  [rc.bb symbolicateWithPaths:rc.paths binaryInfo:rc.binaryImageLines];
																				  [rc write];
																			  }
																		  }
																	  }];
	return rc;
}

- (void)parse {
	[self readLines];
}

- (void)write {
	NSMutableString *symbolicated = [[NSMutableString alloc] init];

	[self.parsedLines enumerateObjectsUsingBlock:^(id<CrashReportLine> line, NSUInteger idx, BOOL *stop) {
		[symbolicated appendString:[line symbolicate]];
		[symbolicated appendString:@"\n"];
	}];

	[symbolicated writeToFile:self.outFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark -
#pragma mark CrashReportParser Private Methods

- (void)readLines {
	__block SectionLine *currentSection;

	[self.lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
		NSInteger count = self.parsedLines.count;

		if ([currentSection.sectionName hasPrefix:@"Last Exception Backtrace"]) {
			ExceptionTraceLine *etl = [ExceptionTraceLine buildWithLine:line andBlackboard:self.bb];
			StackFrameLine *stl = [StackFrameLine buildWithLine:line andBlackboard:self.bb];

			if (stl) {
				[self.parsedLines addObject:stl];
			} else {
				if (etl)
					[self.parsedLines addObject:etl];
				else
					NSLog(@"Expected exception backtrace at line: %lu", idx);
				
				currentSection = nil;
			}
		} else if ([currentSection.sectionName hasPrefix:@"Binary Images"]) {
			BinaryImageLine *bil = [BinaryImageLine buildWithLine:line];
			
			if (bil) {
				[self.parsedLines addObject:bil];
				[self.binaryImageLines addObject:bil];
				dispatch_async(dispatch_get_main_queue(), ^{
					NSPredicate *pred = [NSPredicate predicateWithFormat:@"com_apple_xcode_dsym_uuids LIKE %@", bil.uuid];
					NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
					
					[self.queries addObject:query];
					[query setOperationQueue:self.opQ];
					[query setPredicate:pred];
					[query startQuery];
				});
			} else {
				NSLog(@"Expected binary image description at line: %lu", idx);
			}
		} else if ([currentSection.sectionName hasPrefix:@"Thread"]) {
			StackFrameLine *stl = [StackFrameLine buildWithLine:line andBlackboard:self.bb];
			
			if (stl)
				[self.parsedLines addObject:stl];
			else if (line.length == 0)
				currentSection = nil;
			else
				NSLog(@"Expected stack frame at line: %lu", idx);
		} else {
			currentSection = [SectionLine buildWithLine:line];
			
			if (currentSection)
				[self.parsedLines addObject:currentSection];
		}

		if (self.parsedLines.count == count)
			[self.parsedLines addObject:[InformationalLine buildWithLine:line]];
	}];
}

@end
