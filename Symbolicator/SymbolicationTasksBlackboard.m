#include <pwd.h>
#import "MachOReader.h"
#import "SymbolicationTasksBlackboard.h"

@interface SymbolicationTasksBlackboard()
@property (nonatomic, strong) NSMutableDictionary *addressesAndResults;
@end

@implementation SymbolicationTasksBlackboard

+ (instancetype)build {
	SymbolicationTasksBlackboard *rc = [[self alloc] init];

	rc.addressesAndResults = [NSMutableDictionary dictionary];
	return rc;
}

- (void)addAddress:(uint64_t)address {
	self.addressesAndResults[@(address)] = [NSNull null];
}

- (NSString *)symbolicatedAddress:(uint64_t)address {
	return self.addressesAndResults[@(address)];
}

- (void)symbolicateWithPaths:(NSArray *)paths binaryInfo:(NSArray *)binaryLines {
	NSMutableSet *dirs = [NSMutableSet setWithArray:paths];
	NSString *dir = [[NSString stringWithUTF8String:getpwuid(getuid())->pw_dir] stringByAppendingPathComponent:@"/Library/Developer/Xcode/iOS DeviceSupport"];
	NSMutableSet *symbolFilesNeeded = [NSMutableSet set];
	NSMutableDictionary *binaryToAddress = [NSMutableDictionary dictionary];
	__block NSString *arch = nil;
	void (^symbolicator)(NSString *) = ^(NSString *f) {
		if ([symbolFilesNeeded containsObject:[f lastPathComponent]]) {
			MachOReader *reader = [MachOReader buildWithFile:f];
			__block ThinMachObject *thinMach = nil;

			if (arch) {
				thinMach = [reader objectForArch:arch];
				[thinMach parse];
			} else {
				for (ThinMachObject *potentialObj in reader.allThinObjects) {
					[potentialObj parse];
					[binaryToAddress enumerateKeysAndObjectsUsingBlock:^(BinaryImageLine *bil, NSArray *addrs, BOOL *stop) {
						if ([bil.uuid isEqualToString:potentialObj.uuid]) {
							arch = potentialObj.arch;
							thinMach = potentialObj;
							*stop = YES;
						}
					}];
				}
			}

			if (thinMach) {
				__block NSArray *addresses = nil;
				__block BinaryImageLine *binary;
				
				[binaryToAddress enumerateKeysAndObjectsUsingBlock:^(BinaryImageLine *bil, NSArray *addrs, BOOL *stop) {
					if ([bil.uuid isEqualToString:thinMach.uuid]) {
						binary = bil;
						addresses = addrs;
						*stop = YES;
					}
				}];
				
				if (addresses.count > 0) {
					NSDictionary *d = [thinMach symbolicate:addresses];
					
					if (d) {
						[d enumerateKeysAndObjectsUsingBlock:^(NSNumber *address, NSString *symbol, BOOL *stop) {
							self.addressesAndResults[@([address integerValue] + binary.loadAddress)] = symbol;
						}];
						[binaryToAddress removeObjectForKey:binary];
					}
				}
			}
		}
	};

	[dirs addObject:dir];
	[self.addressesAndResults enumerateKeysAndObjectsUsingBlock:^(NSNumber *a, id obj, BOOL *stop) {
		NSInteger addr = [a integerValue];

		for (BinaryImageLine *bil in binaryLines) {
			if (bil.loadAddress <= addr && bil.endAddress >= addr) {
				NSMutableArray *addresses = binaryToAddress[bil];

				if (!addresses) {
					addresses = [NSMutableArray array];
					binaryToAddress[bil] = addresses;
				}

				[addresses addObject:@(addr - bil.loadAddress)];
				[symbolFilesNeeded addObject:[bil.path lastPathComponent]];
				break;
			}
		}
	}];

	[dirs enumerateObjectsUsingBlock:^(NSString *dir, BOOL *stop) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSDirectoryEnumerator *e = [fm enumeratorAtPath:dir];
		NSString *f;
		BOOL isDir;

		if ([fm fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
			while ((f = [e nextObject]) && binaryToAddress.count > 0) {
				@autoreleasepool {
					f = [dir stringByAppendingPathComponent:f];
					
					if ([fm fileExistsAtPath:f isDirectory:&isDir] && !isDir)
						symbolicator(f);
				}
			}
		} else {
			symbolicator(dir);
		}

		if (binaryToAddress.count == 0)
			*stop = YES;
	}];
}

@end
