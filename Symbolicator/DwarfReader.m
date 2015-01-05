#import "DwarfReader.h"
#import "libdwarf.h"
#import "MachONList.h"
#import "MachOSection.h"

@interface DwarfReader()
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSFileHandle *fH;
@property (nonatomic, assign) Dwarf_Obj_Access_Interface dwarfInterface;
@property (nonatomic, assign) Dwarf_Obj_Access_Methods dwarfMethods;
@property (nonatomic, assign) Dwarf_Debug dbg;
@end

void dwarfPrintf(void *p, const char *l) {
	NSLog(@"%s", l);
}

void dwarfErrHandler(Dwarf_Error err, Dwarf_Ptr ptr) {
	NSLog(@"Dwarf Error: %s", dwarf_errmsg(err));
}

Dwarf_Endianness dwarfGetByteOrder(void *obj) {
	return DW_OBJECT_LSB;
}

// XXX: Should this be 8 for 64-bit?
Dwarf_Small dwarfGetLengthSize(void *obj) {
	return 4;
}

// XXX: Should this be 8 for 64-bit?
Dwarf_Small dwarfGetPtrSize(void *obj) {
	return 4;
}

Dwarf_Unsigned dwarfGetSectionCount(void *obj) {
	DwarfReader *reader = (__bridge DwarfReader *)obj;

	return reader.sections.count;
}

int dwarfGetSectionInfo(void* obj, Dwarf_Half section_index, Dwarf_Obj_Access_Section* return_section, int* error) {
	DwarfReader *reader = (__bridge DwarfReader *)obj;
	MachOSection *section;

	if (section_index >= reader.sections.count) {
		*error = DW_DLE_IA;
		return DW_DLV_ERROR;
	}

	section = reader.sections[section_index];
	return_section -> addr = section.addr;
	return_section -> size = section.size;
	((char *)section.name.mutableBytes)[1] = '.';
	return_section -> name = (char *)section.name.bytes + 1;
	return_section -> link = 0;
	return_section -> entrysize = 0;
	return DW_DLV_OK;
}

int dwarfLoadSection(void* obj, Dwarf_Half section_index, Dwarf_Small** return_data, int* error) {
	DwarfReader *reader = (__bridge DwarfReader *)obj;
	MachOSection *section;
	NSData *data;

	if (section_index >= reader.sections.count) {
		*error = DW_DLE_IA;
		return DW_DLV_ERROR;
	}

	section = reader.sections[section_index];
	[reader.fH seekToFileOffset:section.offset];

	*return_data = malloc(section.size);

	if (!*return_data) {
		*error = DW_DLE_MAF;
		return DW_DLV_ERROR;
	}

	data = [reader.fH readDataOfLength:section.size];
	memcpy(*return_data, data.bytes, section.size);
	return DW_DLV_OK;
}

int dwarfRelocateASection(void* obj, Dwarf_Half section_index, Dwarf_Debug dbg, int* error) {
	*error = DW_DLE_IA;
	return DW_DLV_ERROR;
}

@implementation DwarfReader

+ (DwarfReader *)buildWithSections:(NSArray *)sections forPath:(NSString *)path {
	DwarfReader *rc = [[DwarfReader alloc] init];

	rc.sections = sections;
	rc.fH = [NSFileHandle fileHandleForReadingAtPath:path];

	[rc configureMethods];
	if ([rc load])
		return rc;

	return nil;
}

- (NSDictionary *)symbolicate:(NSMutableDictionary *)addressToSymbol {
	Dwarf_Arange *addressRangesBuffer = 0;
	Dwarf_Signed totalRanges = 0;
	Dwarf_Error err;
	NSMutableDictionary *rc = [NSMutableDictionary dictionary];

	if (dwarf_get_aranges(self.dbg, &addressRangesBuffer, &totalRanges, &err) != DW_DLV_OK) {
		NSLog(@"Error reading aranges: %s", dwarf_errmsg(err));
		return nil;
	}

	[addressToSymbol enumerateKeysAndObjectsUsingBlock:^(NSNumber *a, MachONList *symbol, BOOL *stop) {
		Dwarf_Error err;
		NSInteger addr = [a integerValue] + symbol.segment.vmaddr;
		Dwarf_Arange arange;
		
		if (dwarf_get_arange(addressRangesBuffer, totalRanges, addr, &arange, &err) == DW_DLV_OK) {
			Dwarf_Unsigned segment;
			Dwarf_Unsigned segmentEntrySize;
			Dwarf_Addr start;
			Dwarf_Unsigned length;
			Dwarf_Off cuDieOffset;
			
			if (dwarf_get_arange_info_b(arange, &segment, &segmentEntrySize, &start, &length, &cuDieOffset, &err) == DW_DLV_OK) {
				Dwarf_Die cuDie;
				
				if (dwarf_offdie(self.dbg, cuDieOffset, &cuDie, &err) == DW_DLV_OK) {
					Dwarf_Line *lineBuffer;
					Dwarf_Signed totalLines;
					
					if (dwarf_srclines(cuDie, &lineBuffer, &totalLines, &err) == DW_DLV_OK) {
						NSString *symbol = [self symbolForAddress:addr fromLines:lineBuffer count:totalLines];
						
						if (symbol)
							rc[a] = symbol;
						
						dwarf_srclines_dealloc(self.dbg, lineBuffer, totalLines);
					} else {
						NSLog(@"dwarf_srclines failed: %s", dwarf_errmsg(err));
					}
				} else {
					NSLog(@"dwarf_offdie failed: %s", dwarf_errmsg(err));
				}
			} else {
				NSLog(@"Failed to get arange info for addr %@: %s", a, dwarf_errmsg(err));
			}
			
		} else {
			NSLog(@"Failed to get arange for addr %@: %s", a, dwarf_errmsg(err));
		}
	}];

	dwarf_dealloc(self.dbg, addressRangesBuffer, DW_DLA_ARANGE);

	return rc;
}

#pragma mark -
#pragma mark DwarfReader Private Methods

- (void)configureMethods {
	_dwarfMethods.get_byte_order = dwarfGetByteOrder;
	_dwarfMethods.get_length_size = dwarfGetLengthSize;
	_dwarfMethods.get_pointer_size = dwarfGetPtrSize;
	_dwarfMethods.get_section_count = dwarfGetSectionCount;
	_dwarfMethods.get_section_info = dwarfGetSectionInfo;
	_dwarfMethods.load_section = dwarfLoadSection;
	_dwarfMethods.relocate_a_section = dwarfRelocateASection;
	_dwarfInterface.methods = &_dwarfMethods;
	_dwarfInterface.object = (__bridge void *)self;
}

- (BOOL)load {
	Dwarf_Error err = 0;
	int code;


	if ((code = dwarf_object_init(&_dwarfInterface, dwarfErrHandler, 0, &_dbg, &err)) != DW_DLV_OK) {
		NSLog(@"Init error: %s", dwarf_errmsg(err));
		return NO;
	}

	struct Dwarf_Printf_Callback_Info_s i = { 0};
	i.dp_fptr = dwarfPrintf;
	dwarf_register_printf_callback(self.dbg, &i);

	return YES;
}

- (NSString *)symbolForAddress:(NSInteger)addr fromLines:(Dwarf_Line *)lines count:(Dwarf_Signed)count {
	Dwarf_Error err;

	for (int i = 0; i < count; i++) {
		Dwarf_Addr lowAddr;
		Dwarf_Addr highAddr;

		if (i == 0) {
			dwarf_lineaddr(lines[i], &lowAddr, &err);
		} else {
			dwarf_lineaddr(lines[i - 1], &lowAddr, &err);
			//lowAddr++;
		}

		if (i == count - 1) {
			dwarf_lineaddr(lines[i], &highAddr, &err);
		} else {
			dwarf_lineaddr(lines[i + 1], &highAddr, &err);
			//highAddr--;
		}

		if (addr >= lowAddr && addr <= highAddr) {
			char *fileName;
			Dwarf_Unsigned lineNumber;
			NSString *rc;

			dwarf_linesrc(lines[i], &fileName, &err);
			dwarf_lineno(lines[i], &lineNumber, &err);
			rc = [NSString stringWithFormat:@"%@:%llu", [[NSString stringWithFormat:@"%s", fileName] lastPathComponent], lineNumber];
			dwarf_dealloc(self.dbg, fileName, DW_DLA_STRING);
			return rc;
		}
	}

	return nil;
}

@end
