#import <cxxabi.h>
#import <stdlib.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import "DwarfReader.h"
#import "MachONList.h"
#import "MachOSection.h"
#import "MachOSegment.h"
#import "ThinMachObject.h"

@interface ThinMachObject()
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) BOOL is64Bit;
@property (nonatomic, assign) struct mach_header header;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSInteger start;
@property (nonatomic, assign) NSInteger end;
@property (nonatomic, strong) NSFileHandle *fH;
@property (nonatomic, strong) NSMutableArray *segments;
@property (nonatomic, strong) NSMutableArray *symbolTable;
@property (nonatomic, strong) DwarfReader *dwarfReader;
@end

@implementation ThinMachObject

+ (instancetype)buildWithHandle:(NSFileHandle *)fH size:(NSInteger)size forPath:(NSString *)path {
	ThinMachObject *rc = [[self alloc] init];

	rc.path = path;
	rc.fH = fH;
	rc.start = fH.offsetInFile;
	rc.end = fH.offsetInFile + size;
	rc.segments = [NSMutableArray array];
	rc.symbolTable = [NSMutableArray array];
	[rc readHeader];
	return rc;
}

- (NSDictionary *)symbolicate:(NSArray *)addresses {
	NSMutableDictionary *rc = [NSMutableDictionary dictionary];
	NSMutableDictionary *addressToSymbol = [NSMutableDictionary dictionary];
	NSDictionary *addressToLineNum;

	if (self.symbolTable.count < 2)
		return nil;

	for (NSNumber *a in addresses) {
		NSInteger addr = [a integerValue];
		MachONList *best = nil;
		NSInteger bestOffset = 0;
		NSInteger adjAddr;

		for (MachONList *nlist in self.symbolTable) {
			MachOSegment *s = nlist.segment;

			if (nlist.value - s.vmaddr < addr) {
				best = nlist;
				adjAddr = addr + s.vmaddr;
				bestOffset = addr - nlist.value + s.vmaddr;
			} else {
				break;
			}
		}

		if (best)
			addressToSymbol[a] = best;
	}

	addressToLineNum = [self.dwarfReader symbolicate:addressToSymbol];

	[addressToSymbol enumerateKeysAndObjectsUsingBlock:^(NSNumber *a, MachONList *best, BOOL *stop) {
		int status = 0;
		const char *cppname = [best.symbol UTF8String];
		NSString *symbol = best.symbol;
		const char *name = NULL;
		NSString *lineNumberSymbol = addressToLineNum[a];
		
		if (cppname[0] == '_')
			name = abi::__cxa_demangle(cppname + 1, 0, 0, &status);
		else
			name = abi::__cxa_demangle(cppname, 0, 0, &status);
		
		if (name) {
			if (status == 0)
				symbol = [NSString stringWithUTF8String:name];
			
			free((void *)name);
		}
		
		if (lineNumberSymbol)
			rc[a] = [NSString stringWithFormat:@"%@ %@", symbol, lineNumberSymbol];
		else
			rc[a] = [NSString stringWithFormat:@"%@ + %ld", symbol, [a integerValue] - best.value + best.segment.vmaddr];
	}];

	return rc;
}

#pragma mark -
#pragma ThinMachObject Private Methods

- (void)readHeader {
	NSData *d = [self.fH readDataOfLength:sizeof(struct mach_header)];

	self.header = *((struct mach_header *)d.bytes);

	if (self.header.magic == MH_CIGAM || self.header.magic == MH_CIGAM_64)
		assert(false); // For arm and x86, this should never happen, little-endian archs all around

	if (self.header.cputype == CPU_TYPE_X86_64 || self.header.cputype == CPU_TYPE_ARM64) {
		self.is64Bit = YES;
		[self.fH seekToFileOffset:self.fH.offsetInFile + sizeof(struct mach_header_64) - sizeof(struct mach_header)];
	}

	self.arch = [self prettyArchFromCPUType:self.header.cputype andSubType:self.header.cpusubtype];
	self.offset = self.fH.offsetInFile;
}

- (NSString *)prettyArchFromCPUType:(cpu_type_t)type andSubType:(cpu_subtype_t)subType {
	NSString *rc = nil;

	if (type == CPU_TYPE_I386) {
		rc = @"i386";
	} else if (type == CPU_TYPE_X86_64) {
		rc = @"x86_64";
	} else if (type == CPU_TYPE_ARM) {
		if (subType == CPU_SUBTYPE_ARM_V6)
			rc = @"armv6";
		else if (subType == CPU_SUBTYPE_ARM_V7)
			rc = @"armv7";
		else if (subType == CPU_SUBTYPE_ARM_V7S)
			rc = @"armv7s";
		else if (subType == CPU_SUBTYPE_ARM_V8)
			rc = @"armv8";
	} else if (type == CPU_TYPE_ARM64) {
		rc = @"arm64";
	}

	return rc;
}

- (void)parse {
	[self.fH seekToFileOffset:self.offset];

	for (int i = 0; i < self.header.ncmds; i++) {
		@autoreleasepool {
			NSData *d = [self.fH readDataOfLength:sizeof(struct load_command)];
			struct load_command *lc = (struct load_command *)d.bytes;
			
			if (lc -> cmd == LC_UUID) {
				[self readUUID];
			} else if (lc -> cmd == LC_SEGMENT || lc -> cmd == LC_SEGMENT_64) {
				[self.fH seekToFileOffset:self.fH.offsetInFile - sizeof(struct load_command)];
				[self readSegment];
			} else if (lc -> cmd == LC_SYMTAB) {
				[self.fH seekToFileOffset:self.fH.offsetInFile - sizeof(struct load_command)];
				[self readSymtab];
			} else {
				[self.fH seekToFileOffset:self.fH.offsetInFile - sizeof(struct load_command) + lc -> cmdsize];
			}
		}
	}

	for (MachONList *nlist in self.symbolTable) {
		if (nlist.section != NO_SECT) {
			__block NSInteger sectionStart = 0;
			
			[self.segments enumerateObjectsUsingBlock:^(MachOSegment *seg, NSUInteger idx, BOOL *stop) {
				if (seg.nsects + sectionStart >= nlist.section) {
					nlist.segment = seg;
					*stop = YES;
				} else {
					sectionStart += seg.nsects;
				}
			}];
		} else {
			assert(false);
		}
	}
}

- (void)readUUID {
	NSData *d = [self.fH readDataOfLength:16];

	self.uuid = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)d.bytes].UUIDString;
}

- (void)readSegment {
	NSData *d = [self.fH readDataOfLength:self.is64Bit ? sizeof(struct segment_command_64) : sizeof(struct segment_command)];
	MachOSegment *segment = [self parseSegment:d];

	[self.segments addObject:segment];
	[self.fH seekToFileOffset:self.fH.offsetInFile - d.length + segment.cmdSize];
}

- (void)readSymtab {
	NSData *d = [self.fH readDataOfLength:sizeof(struct symtab_command)];
	NSData *syms = nil;
	NSData *strs = nil;
	struct symtab_command *symtab = (struct symtab_command *)d.bytes;
	NSInteger offset = self.fH.offsetInFile;

	[self.fH seekToFileOffset:self.start + symtab -> symoff];
	syms = [self.fH readDataOfLength:symtab -> nsyms * (self.is64Bit ? sizeof(struct nlist_64) : sizeof(struct nlist))];
	[self.fH seekToFileOffset:self.start + symtab -> stroff];
	strs = [self.fH readDataOfLength:symtab -> strsize];

	[self parseSymbolTable:symtab withTableData:syms andStringData:strs];
	[self.fH seekToFileOffset:offset];
}

- (MachOSegment *)parseSegment:(NSData *)d {
	MachOSegment *rc = [[MachOSegment alloc] init];

	if (self.is64Bit) {
		struct segment_command_64 *sc = (struct segment_command_64 *)d.bytes;

		rc.name = [[NSString alloc] initWithBytes:sc -> segname length:16 encoding:NSUTF8StringEncoding];
		rc.cmd = sc -> cmd;
		rc.cmdSize = sc -> cmdsize;
		rc.vmaddr = sc -> vmaddr;
		rc.vmsize = sc -> vmsize;
		rc.fileoff = sc -> fileoff;
		rc.filesize = sc -> filesize;
		rc.nsects = sc -> nsects;
		rc.flags = sc -> flags;
	} else {
		struct segment_command *sc = (struct segment_command *)d.bytes;

		rc.name = [[NSString alloc] initWithBytes:sc -> segname length:16 encoding:NSUTF8StringEncoding];
		rc.cmd = sc -> cmd;
		rc.cmdSize = sc -> cmdsize;
		rc.vmaddr = sc -> vmaddr;
		rc.vmsize = sc -> vmsize;
		rc.fileoff = sc -> fileoff;
		rc.filesize = sc -> filesize;
		rc.nsects = sc -> nsects;
		rc.flags = sc -> flags;
	}

	if ([rc.name hasPrefix:@"__DWARF"])
		[self parseDwarfSegment:rc];

	return rc;
}

- (void)parseSymbolTable:(struct symtab_command *)symtab withTableData:(NSData *)syms andStringData:(NSData *)strs {
	assert(self.symbolTable.count == 0);
	
	if (self.is64Bit) {
		struct nlist_64 *nlist = (struct nlist_64 *)syms.bytes;

		for (int i = 0; i < symtab -> nsyms; i++) {
			if ((nlist[i].n_type & N_TYPE) == N_SECT) {
				MachONList *n = [[MachONList alloc] init];

				n.idx = nlist[i].n_un.n_strx;
				n.section = nlist[i].n_sect;
				n.value = nlist[i].n_value;

				if (n.idx != 0)
					n.symbol = [NSString stringWithUTF8String:(char *)strs.bytes + n.idx];

				[self.symbolTable addObject:n];
			}
		}
	} else {
		struct nlist *nlist = (struct nlist *)syms.bytes;

		for (int i = 0; i < symtab -> nsyms; i++) {
			if ((nlist[i].n_type & N_TYPE) == N_SECT && (nlist[i].n_type & N_STAB) == 0) {
				MachONList *n = [[MachONList alloc] init];

				n.idx = nlist[i].n_un.n_strx;
				n.section = nlist[i].n_sect;
				n.value = nlist[i].n_value;

				if (n.idx != 0)
					n.symbol = [NSString stringWithUTF8String:(char *)strs.bytes + n.idx];

				[self.symbolTable addObject:n];
			}
		}
	}

	[self.symbolTable sortUsingComparator:^NSComparisonResult(MachONList *l, MachONList *r) {
		if (l.value < r.value)
			return NSOrderedAscending;

		if (l.value > r.value)
			return NSOrderedDescending;

		return NSOrderedSame;
	}];
}

- (void)parseDwarfSegment:(MachOSegment *)segment {
	NSMutableArray *sections = [NSMutableArray array];

	for (int i = 0; i < segment.nsects; i++) {
		MachOSection *s = [self parseSection:[self.fH readDataOfLength:self.is64Bit ? sizeof(struct section_64) : sizeof(struct section)]];

		[sections addObject:s];
	}

	self.dwarfReader = [DwarfReader buildWithSections:sections forPath:self.path];
}

- (MachOSection *)parseSection:(NSData *)d {
	MachOSection *rc = [[MachOSection alloc] init];

	if (self.is64Bit) {
		struct section_64 *s = (struct section_64 *)d.bytes;

		rc.name = [NSMutableData dataWithBytes:s -> sectname length:16];
		rc.addr = s -> addr;
		rc.size = s -> size;
		rc.offset = self.start + s -> offset;
		rc.align = s -> align;
		rc.reloff = s -> reloff;
		rc.flags = s -> flags;
	} else {
		struct section *s = (struct section *)d.bytes;

		rc.name = [NSMutableData dataWithBytes:s -> sectname length:16];
		rc.addr = s -> addr;
		rc.size = s -> size;
		rc.offset = self.start + s -> offset;
		rc.align = s -> align;
		rc.reloff = s -> reloff;
		rc.flags = s -> flags;
	}

	return rc;
}

@end
