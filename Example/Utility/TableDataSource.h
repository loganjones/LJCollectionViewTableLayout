//
//  TableDataSource.h
//  Example
//
//  Created by Logan Jones on 9/15/13.
//  Copyright (c) 2013 Logan Jones. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface TableDataSource : NSObject

- (instancetype)initWithCsvFileAtPath:(NSString *)path;
+ (instancetype)newWithCsvFileAtPath:(NSString *)path;


- (NSInteger)numberOfColumns;
- (NSInteger)numberOfRows;

- (NSString *)nameOfColumnAtIndex:(NSInteger)columnIndex;
- (NSString *)stringInRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex;

@end
