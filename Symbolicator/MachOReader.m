#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import "MachOReader.h"
#import "ThinMachObject.h"

@interface MachOReader()
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSFileHandle *fH;
@property (nonatomic, strong) NSMutableDictionary *thinMachObjects;
@end

@implementation MachOReader

+ (instancetype)buildWithFile:(NSString *)file {
	MachOReader *rc = [[self alloc] init];

	rc.path = file;
	rc.thinMachObjects = [NSMutableDictionary dictionary];
	rc.fH = [NSFileHandle fileHandleForReadingAtPath:file];
	[rc readInitialHeaders];
	return rc;
}

- (NSInteger)totalArchitectures {
	return self.thinMachObjects.count;
}

- (NSArray *)allThinObjects {
	return [self.thinMachObjects allValues];
}

- (BOOL)hasArch:(NSString *)arch {
	return self.thinMachObjects[arch] != nil;
}

- (ThinMachObject *)objectForArch:(NSString *)arch {
	return self.thinMachObjects[arch];
}

#pragma mark -
#pragma mark MachOReader Private Methods

- (void)readInitialHeaders {
	uint32_t magic = 0;
	NSData *d = [self.fH readDataOfLength:sizeof(magic)];

	magic = *((uint32_t *)d.bytes);
	[self.fH seekToFileOffset:0];

	if (magic == FAT_CIGAM) {
		[self readFatHeaders];
	} else {
		ThinMachObject *o = nil;
		NSInteger size;

		[self.fH seekToEndOfFile];
		size = self.fH.offsetInFile;
		[self.fH seekToFileOffset:0];
		o = [ThinMachObject buildWithHandle:self.fH size:size forPath:self.path];

		if (o)
			self.thinMachObjects[o.arch] = o;
	}
}

- (void)readFatHeaders {
	struct fat_header header = { 0 };
	struct fat_arch *archs = 0;
	NSInteger archBytes;
	NSData *d = [self.fH readDataOfLength:sizeof(header)];

	header = *((struct fat_header *)d.bytes);
	header.nfat_arch = CFSwapInt32BigToHost(header.nfat_arch);

	archBytes = sizeof(struct fat_arch) * header.nfat_arch;
	d = [self.fH readDataOfLength:archBytes];
	archs = (struct fat_arch *)d.bytes;

	for (int i = 0; i < header.nfat_arch; i++) {
		NSInteger offset = CFSwapInt32BigToHost(archs[i].offset);
		ThinMachObject *o = nil;

		[self.fH seekToFileOffset:offset];
		o = [ThinMachObject buildWithHandle:self.fH size:CFSwapInt32BigToHost(archs[i].size) forPath:(NSString *)self.path];

		if (o)
			self.thinMachObjects[o.arch] = o;
	}
}

@end
