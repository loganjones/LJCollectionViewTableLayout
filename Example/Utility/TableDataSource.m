//
//  TableDataSource.m
//  Example
//
//  Created by Logan Jones on 9/15/13.
//  Copyright (c) 2013 Logan Jones. All rights reserved.
//

#import "TableDataSource.h"
#import "CHCSVParser.h"

@interface TableDataSource () <CHCSVParserDelegate>
@property (nonatomic, strong) NSMutableArray *columns;
@property (nonatomic, strong) NSMutableArray *data;
@property (nonatomic) NSInteger numberOfRows;

@property (nonatomic) BOOL hasReadHeader;
@property (nonatomic, strong) NSMutableArray *fields;
@end





@implementation TableDataSource

- (instancetype)initWithCsvFileAtPath:(NSString *)path {
    self = [super init];
    if (self) {
        CHCSVParser *parser = [[CHCSVParser alloc] initWithContentsOfCSVFile:path];
        parser.delegate = self;
        parser.sanitizesFields = YES;
        [parser parse];
    }
    return self;
}

+ (instancetype)newWithCsvFileAtPath:(NSString *)path {
    return [[TableDataSource alloc] initWithCsvFileAtPath:path];
}





- (NSInteger)numberOfColumns {
    return self.columns.count;
}



- (NSString *)nameOfColumnAtIndex:(NSInteger)columnIndex {
    return self.columns[columnIndex];
}



- (NSString *)stringInRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex {
    if (rowIndex < self.numberOfRows  &&  columnIndex < self.numberOfColumns) {
        NSInteger dataIndex = (rowIndex * self.numberOfColumns) + columnIndex;
        if (dataIndex < self.data.count) {
            id dataItem = self.data[dataIndex];
            if ([dataItem isKindOfClass:[NSString class]])
                return dataItem;
        }
    }

    return nil;
}





#pragma mark - CHCSVParserDelegate

- (void)parserDidBeginDocument:(CHCSVParser *)parser {
    _numberOfRows = 0;
    _hasReadHeader = NO;
    _columns = [NSMutableArray arrayWithCapacity:1];
    _data = nil;
}

- (void)parserDidEndDocument:(CHCSVParser *)parser {
    NSAssert(self.data.count == (self.numberOfRows * self.numberOfColumns), @"Number of data cells does not match rows*columns");
}

- (void)parser:(CHCSVParser *)parser didBeginLine:(NSUInteger)recordNumber {
    if (self.hasReadHeader) {
        self.fields = [NSMutableArray arrayWithCapacity:self.numberOfColumns];
    } else {
        self.fields = [NSMutableArray arrayWithCapacity:1];
    }
}

- (void)parser:(CHCSVParser *)parser didEndLine:(NSUInteger)recordNumber {
    if (self.hasReadHeader) {
        if (self.fields.count == self.numberOfColumns) {
            [self.data addObjectsFromArray:self.fields];
            ++self.numberOfRows;
        } else if (self.fields.count > 1  &&  self.fields.count < self.numberOfColumns) {
            [self.data addObjectsFromArray:self.fields];
            NSInteger null_count = self.numberOfColumns - self.fields.count;
            for (NSInteger i = 0; i < null_count; ++i) {
                [self.data addObject:@""];
            }
            ++self.numberOfRows;
        }
        self.fields = nil;
        
    } else {
        self.columns = self.fields;
        self.fields = nil;
        self.hasReadHeader = YES;
        self.data = [NSMutableArray arrayWithCapacity:self.numberOfColumns];
    }
}

- (void)parser:(CHCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex {
    [self.fields addObject:field];
}

- (void)parser:(CHCSVParser *)parser didReadComment:(NSString *)comment {
    NSLog(@"CSV comment: %@", comment);
}

- (void)parser:(CHCSVParser *)parser didFailWithError:(NSError *)error {
    NSLog(@"CSV parse failed: %@", error.localizedDescription);
}

@end
