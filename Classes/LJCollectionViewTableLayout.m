//
//  LJCollectionViewTableLayout.m
//  Simply SQL iOS
//
//  Created by Logan Jones on 9/3/13.
//  Copyright (c) 2013 Toasty. All rights reserved.
//

#import "LJCollectionViewTableLayout.h"


// I use DbgLog in place of NSLog. Makes it easy to turn on and off at compile time.
#ifdef DEBUG
# if (0)
#   define DbgLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#   define DbgDetailLog(fmt, ...) NSLog((@"[Line %d] %s " fmt), __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__)
# else
#   define DbgLog(...)
#   define DbgDetailLog(...)
# endif
#else
#   define DbgLog(...)
#   define DbgDetailLog(...)
#endif


// Attribute caching flags
// Generated UICollectionViewLayoutAttributes can be precomputed and cached in prepareLayout.
#define CACHE_HEADER_LAYOUT_ATTRIBUTES  1
#define CACHE_COLUMN_SEPARATOR_ATTRIBUTES   1

// Quick flags for turning off functionality for testing.
#define SHOW_HEADER                     1
#define SHOW_HEADER_BG                  1
#define SHOW_ROW_BG                     1
#define SHOW_SEPARATORS                 1

// Support for iOS 7 UICollectionViewLayoutInvalidationContext
// This work has only just begun; only exploratory for now.
#define USE_INVALIDATION_CONTEXT        0


NSString *const LJCollectionViewTableLayoutElementKindColumnHeader = @"LJCollectionViewTableLayoutElementKindColumnHeader";
NSString *const LJCollectionViewTableLayoutElementKindColumnHeaderBackground = @"LJCollectionViewTableLayoutElementKindColumnHeaderBackground";
NSString *const LJCollectionViewTableLayoutElementKindRowBackground = @"LJCollectionViewTableLayoutElementKindRowBackground";
NSString *const LJCollectionViewTableLayoutElementKindTableBackground = @"LJCollectionViewTableLayoutElementKindTableBackground";
NSString *const LJCollectionViewTableLayoutElementKindColumnSeparators = @"LJCollectionViewTableLayoutElementKindColumnSeparators";


// z index values for various interface elements.
// It's easier to manage them here than if they were spread all over the source file.
const NSInteger
    SectionBacground_zIndex = 0,
    RowBackground_zIndex = 10,
    Cell_zIndex = 11,
    HeaderBackground_zIndex = 100,
    ColumnHeaderView_zIndex = 101,
    ColumnSeparators_zIndex = 1000;


//#import "CGFloatRange.h"
//#import "CGFloat+Extra.h"
static inline CGFloat CGFloatCeil(CGFloat value);
static inline CGFloat CGFloatFloor(CGFloat value);


/// Properties of a table column that we need to keep track of.
@interface LJCollectionViewTableColumnMetrics : NSObject
@property (nonatomic) CGFloat width, offset;
@end
@implementation LJCollectionViewTableColumnMetrics
@end


/// Appearance properties for a row's background.
@interface LJCollectionViewTableLayoutRowViewAttributes : UICollectionViewLayoutAttributes
@property (nonatomic, retain) UIColor *backgroundColor;
@end
@implementation LJCollectionViewTableLayoutRowViewAttributes
@end

/// @brief Draws the background for each data row.
/// @see LJCollectionViewTableLayoutRowViewAttributes
@interface LJCollectionViewTableLayoutRowBackgroundView : UICollectionReusableView
@end


/// Draws the column lines on top of the entire table display.
@interface LJCollectionViewTableLayoutColumnSeparatorsView : UICollectionReusableView
@end


/// Attributes that are routed to an LJCollectionViewTableLayoutColumnSeparatorsView instance.
@interface LJCollectionViewTableLayoutColumnSeparatorsViewAttributes : UICollectionViewLayoutAttributes
@property (nonatomic) UIColor *separatorColor;
@end
@implementation LJCollectionViewTableLayoutColumnSeparatorsViewAttributes
@end


/// Container of all meta-data needed for a table.
@interface LJCollectionViewTableSection : NSObject
@property (nonatomic) NSInteger index;
@property (nonatomic) NSInteger numberOfRows, numberOfColumns;
@property (nonatomic, strong) NSArray *columnMetrics;

@property (nonatomic) CGFloat totalWidthOfAllColumns, totalHeightOfLayout;
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
@property (nonatomic, strong) NSArray *headerAttributes;
@property (nonatomic, strong) UICollectionViewLayoutAttributes *headerBackgroundAttributes;
#endif
#if (CACHE_COLUMN_SEPARATOR_ATTRIBUTES)
@property (nonatomic, strong) NSArray *columnSeparatorAttributes;
#endif
@property (nonatomic, strong) LJCollectionViewTableLayoutRowViewAttributes *tableBackgroundAttributes;
- (NSRange)columnsCoveredByRect:(CGRect)rect;
- (NSInteger)itemIndexForTablePosition:(LJCollectionViewTableLayoutTablePosition)tablePosition;
- (NSIndexPath *)indexPathForTablePosition:(LJCollectionViewTableLayoutTablePosition)tablePosition;
@end


#if (USE_INVALIDATION_CONTEXT)
NS_CLASS_AVAILABLE_IOS(7_0) @interface LJCollectionViewTableLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
@property (nonatomic) BOOL invalidateFloatingViews;
@end
#endif





@interface LJCollectionViewTableLayout ()
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic) CGSize contentSize;
@property (nonatomic) BOOL shouldOnlyUpdateFloatingViewsOnPrepareLayout;

@property (nonatomic, strong) NSArray *layoutElementCache;
@property (nonatomic) CGRect rectForLayoutElementCache;
@end

@implementation LJCollectionViewTableLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        _numberOfRows = 0;
        _numberOfColumns = 0;
        _rowHeight = 21;
        _columnWidth = 100;
        _headerHeight = 21;
        _rowSeparatorWidth = 1.0 / [UIScreen mainScreen].scale;
        _rowSeparatorColor = [UIColor lightGrayColor];
        _columnSeparatorWidth = 1;
        _columnSeparatorColor = [UIColor lightGrayColor];
        _shouldFloatHeader = YES;
        _shouldOnlyUpdateFloatingViewsOnPrepareLayout = NO;
        _headerBackgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        _oddRowBackgroundColor = [UIColor colorWithWhite:1 alpha:1];
        _evenRowBackgroundColor = [UIColor colorWithWhite:0.98 alpha:1];
        
        [self registerClass:[LJCollectionViewTableLayoutRowBackgroundView class]
    forDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeaderBackground];
        [self registerClass:[LJCollectionViewTableLayoutRowBackgroundView class]
    forDecorationViewOfKind:LJCollectionViewTableLayoutElementKindRowBackground];
        [self registerClass:[LJCollectionViewTableLayoutRowBackgroundView class]
    forDecorationViewOfKind:LJCollectionViewTableLayoutElementKindTableBackground];
        [self registerClass:[LJCollectionViewTableLayoutColumnSeparatorsView class]
    forDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnSeparators];
    }
    return self;
}



- (void)setNumberOfRows:(NSInteger)numberOfRows {
    DbgDetailLog(@"%d", numberOfRows);
    _numberOfRows = numberOfRows;
    //[self invalidateLayout];
}

- (void)setNumberOfColumns:(NSInteger)numberOfColumns {
    DbgDetailLog(@"%d", numberOfColumns);
    _numberOfColumns = numberOfColumns;
    //[self invalidateLayout];
}



#if (USE_INVALIDATION_CONTEXT)
+ (Class)invalidationContextClass {
    return [LJCollectionViewTableLayoutInvalidationContext class];
}



- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context {
    DbgDetailLog(@"%@", context);
    [super invalidateLayoutWithContext:context];
    
}
#endif



- (void)prepareLayout {
    
    // Let's see if we can cheat and do a simple partial update.
    // The _shouldOnlyUpdateFloatingViewsOnPrepareLayout is usually set on bounds changes.
    
    if (_shouldOnlyUpdateFloatingViewsOnPrepareLayout) { // Yay, a fast partial update
        DbgDetailLog(@" (partial)");
        [self updateLayoutForFloatingViews];
        _shouldOnlyUpdateFloatingViewsOnPrepareLayout = NO; // reset the flag
        
        
    } else { // Prepare a full build of the layout meta data
        DbgDetailLog(@" (full)");
    
        // Clear the attribute cache
        self.layoutElementCache = nil;
        self.rectForLayoutElementCache = CGRectZero;
        
        // Prepare a layout for each section
        const NSInteger numberOfSections = [self.collectionView numberOfSections];
        NSMutableArray *sections = [NSMutableArray arrayWithCapacity:numberOfSections];
        
        // Uhh... TODO
        // For now, just assume one section.
        LJCollectionViewTableSection *section = [self prepareLayoutForSectionAtIndex:0];
        [sections addObject:section];
        
        self.contentSize = CGSizeMake(section.totalWidthOfAllColumns, section.totalHeightOfLayout);
        self.sections = sections;
    }
}



- (LJCollectionViewTableSection *)prepareLayoutForSectionAtIndex:(NSInteger)sectionIndex {
    UICollectionView *cv = self.collectionView;
    id<LJCollectionViewDataSourceTableLayout> dataSource = (id)cv.dataSource;
    id<LJCollectionViewDelegateTableLayout> delegate = (id)cv.delegate;
    
    LJCollectionViewTableSection *section = [LJCollectionViewTableSection new];
    section.index = sectionIndex;
    
    
    // How many columns does this section have? Start with the default but don't forget to ask the delegate.
    NSInteger numberOfColumns = self.numberOfColumns;
    if ([dataSource respondsToSelector:@selector(collectionView:layout:numberOfColumnsForTableInSection:)]) {
        numberOfColumns = [dataSource collectionView:cv layout:self numberOfColumnsForTableInSection:sectionIndex];
    }
    section.numberOfColumns = numberOfColumns;
    
    
    // The layout needs to know how wide each column is (and store this as meta-data).
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:numberOfColumns];
    
    BOOL can_call_get_width = [delegate respondsToSelector:@selector(collectionView:layout:widthOfColumn:forTableInSection:)];
    CGFloat totalWidthOfAllColumns = 0;
    const CGFloat default_width = self.columnWidth;
    
    for (NSInteger i=0; i<numberOfColumns; ++i) {
        if (i > 0)
            totalWidthOfAllColumns += self.columnSeparatorWidth;
        
        CGFloat width;
        if (can_call_get_width) {
            width = [delegate collectionView:cv layout:self widthOfColumn:i forTableInSection:sectionIndex];
            if (width <= 0)
                width = default_width;
        } else
            width = default_width;
        
        LJCollectionViewTableColumnMetrics *metric = [LJCollectionViewTableColumnMetrics new];
        metric.width = width;
        metric.offset = totalWidthOfAllColumns;
        [columns addObject:metric];
        
        totalWidthOfAllColumns += width;
    }
    
    section.totalWidthOfAllColumns = totalWidthOfAllColumns;
    section.columnMetrics = columns;
    
    
    // How many rows does this section have? Start with the default but don't forget to ask the delegate.
    NSInteger numberOfRows = self.numberOfRows;
    if ([dataSource respondsToSelector:@selector(collectionView:layout:numberOfRowsForTableInSection:)]) {
        numberOfRows = [dataSource collectionView:cv layout:self numberOfRowsForTableInSection:sectionIndex];
    }
    section.numberOfRows = numberOfRows;
    
    const CGFloat rowHeight = self.rowHeight, rowSeparatorWidth = self.rowSeparatorWidth;
    const CGFloat headerHeight = self.headerHeight;
    
    
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
    // Build & cache the attributes for each column header.
    const CGFloat header_y = (self.shouldFloatHeader) ? [self contentOffsetForFloatingAtTopOfSection:section] : 0;
    const UIEdgeInsets headerViewInsets = self.headerViewInsets;
    NSMutableArray *header_attributes = [NSMutableArray arrayWithCapacity:numberOfColumns];
    
    for (NSInteger column_i = 0; column_i < numberOfColumns; ++column_i) {
        LJCollectionViewTableColumnMetrics *columnMetrics = columns[column_i];
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:column_i inSection:sectionIndex];
        UICollectionViewLayoutAttributes *header = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeader withIndexPath:indexPath];
        header.frame = UIEdgeInsetsInsetRect(CGRectMake(columnMetrics.offset, header_y, columnMetrics.width, headerHeight), headerViewInsets);
        header.zIndex = ColumnHeaderView_zIndex;
        [header_attributes addObject:header];
    }
    
    section.headerAttributes = header_attributes;
    
    // The header "row" also needs its own background.
    {
        LJCollectionViewTableLayoutRowViewAttributes *header_background = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeaderBackground withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
        header_background.frame = CGRectMake(0, header_y, totalWidthOfAllColumns, self.headerHeight);
        header_background.zIndex = HeaderBackground_zIndex;
        header_background.backgroundColor = self.headerBackgroundColor;
        section.headerBackgroundAttributes = header_background;
    }
#endif
    
    section.totalHeightOfLayout = headerHeight + ((numberOfRows * (rowHeight + rowSeparatorWidth)) - rowSeparatorWidth);
    
    
    // Cache the attributes for the section's background.
    // This will essentially be the row lines due to the gap betwwen each row that allows the under-view to show through.
    // I think this is better than having several row-line-views.
    LJCollectionViewTableLayoutRowViewAttributes *bg = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindTableBackground withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
    bg.frame = CGRectMake(0, 0, totalWidthOfAllColumns, section.totalHeightOfLayout);
    bg.zIndex = SectionBacground_zIndex;
    bg.backgroundColor = self.rowSeparatorColor;
    section.tableBackgroundAttributes = bg;
    
    
#if (CACHE_COLUMN_SEPARATOR_ATTRIBUTES)
    // Build & cache the attributes for each column-line. These lines "float" with the scroll like the headers so their height only needs to be as tall as the visible area.
    {
        NSMutableArray *separator_attributes = [NSMutableArray arrayWithCapacity:numberOfColumns];
        const CGFloat height = cv.bounds.size.height;
        for (NSInteger column_i = 0; column_i < numberOfColumns; ++column_i) {
            LJCollectionViewTableColumnMetrics *columnMetrics = columns[column_i];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:column_i inSection:sectionIndex];
            LJCollectionViewTableLayoutColumnSeparatorsViewAttributes *separator = [LJCollectionViewTableLayoutColumnSeparatorsViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnSeparators withIndexPath:indexPath];
            separator.frame = CGRectMake(columnMetrics.offset + columnMetrics.width, header_y, self.columnSeparatorWidth, height);
            separator.zIndex = ColumnSeparators_zIndex;
            separator.separatorColor = self.columnSeparatorColor;
            [separator_attributes addObject:separator];
        }
        
        section.columnSeparatorAttributes = separator_attributes;
    }
#endif
    

    return section;
}



- (void)updateLayoutForFloatingViews {
    DbgDetailLog(@"");
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
    LJCollectionViewTableSection *section = self.sections[0];
    const CGFloat header_y = [self contentOffsetForFloatingAtTopOfSection:section];
    const CGFloat header_top_inset = self.headerViewInsets.top;
    
    for (UICollectionViewLayoutAttributes *header in section.headerAttributes) {
        CGRect frame = header.frame;
        frame.origin.y = header_y + header_top_inset;
        header.frame = frame;
    }
    
    
    {
        CGRect frame = section.headerBackgroundAttributes.frame;
        frame.origin.y = header_y;
        section.headerBackgroundAttributes.frame = frame;
    }
#endif
    
    
#if (CACHE_COLUMN_SEPARATOR_ATTRIBUTES)
    const CGFloat height = self.collectionView.bounds.size.height;
    for (UICollectionViewLayoutAttributes *separator in section.columnSeparatorAttributes) {
        CGRect frame = separator.frame;
        frame.origin.y = header_y + header_top_inset;
        frame.size.height = height;
        separator.frame = frame;
    }
#endif
    
}



- (CGSize)collectionViewContentSize {
    DbgDetailLog(@":%@", NSStringFromCGSize(_contentSize));
    return _contentSize;
}



- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    if (_shouldFloatHeader) {
        _shouldOnlyUpdateFloatingViewsOnPrepareLayout = YES;
        return YES;
    }
    
    else
        return NO;
}



#if (USE_INVALIDATION_CONTEXT)
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds {
    UICollectionViewLayoutInvalidationContext *context = [super invalidationContextForBoundsChange:newBounds];
    if ([context isKindOfClass:[LJCollectionViewTableLayoutInvalidationContext class]]) {
        ((LJCollectionViewTableLayoutInvalidationContext *)context).invalidateFloatingViews = YES;
    }
    return context;
}
#endif



- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    if (self.layoutElementCache && CGRectEqualToRect(rect, self.rectForLayoutElementCache)) {
        DbgDetailLog(@"%@ (cached)", NSStringFromCGRect(rect));
        return self.layoutElementCache;
        
    } else {
        DbgDetailLog(@"%@ (fresh)", NSStringFromCGRect(rect));
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
        [self addLayoutAttributes:array forElementsFromSection:self.sections[0] inRect:rect];
        self.layoutElementCache = array;
        self.rectForLayoutElementCache = rect;
        return array;
    }
}



- (NSInteger)addLayoutAttributes:(NSMutableArray *)array forElementsFromSection:(LJCollectionViewTableSection *)section inRect:(CGRect)rect {
    
    if (section.numberOfColumns <= 0) {
        return 0;
    }
    
    const NSInteger count_at_start = array.count;
    const NSInteger sectionIndex = section.index;
    
    const NSRange column_range = [section columnsCoveredByRect:rect];
    const CGFloat minY = MAX(CGRectGetMinY(rect), 0), maxY = CGRectGetMaxY(rect), row_height = self.rowHeight + self.rowSeparatorWidth;
    const NSInteger firstRow = MAX(CGFloatFloor(minY / row_height), 0);
    const NSInteger lastRow = MIN(CGFloatFloor((maxY-1) / row_height), section.numberOfRows-1);
    DbgLog(@"     rows %d to %d, cols %d to %d", firstRow, lastRow, column_range.location, NSMaxRange(column_range)-1);
    
#if (SHOW_HEADER)
    if (self.shouldFloatHeader || rect.origin.y < self.headerHeight) {
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
        [array addObject:section.headerBackgroundAttributes];
#else
        const CGFloat header_y = (self.shouldFloatHeader) ? [self contentOffsetForFloatingAtTopOfSection:section] : 0;
        LJCollectionViewTableLayoutRowViewAttributes *header_background = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeaderBackground withIndexPath:[NSIndexPath indexPathForItem:0 inSection:sectionIndex]];
        header_background.frame = CGRectMake(0, header_y, section.totalWidthOfAllColumns, self.headerHeight);
        header_background.zIndex = HeaderBackground_zIndex;
        header_background.backgroundColor = self.headerBackgroundColor;
        [array addObject:header_background];
#endif
        
        for (NSInteger column_i = column_range.location; column_i < NSMaxRange(column_range); ++column_i) {
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
            UICollectionViewLayoutAttributes *header = section.headerAttributes[column_i];
            [array addObject:header];
#else
            LJCollectionViewTableColumnMetrics *columnMetrics = section.columnMetrics[column_i];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:column_i inSection:sectionIndex];
            UICollectionViewLayoutAttributes *header = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeader withIndexPath:indexPath];
            header.frame = UIEdgeInsetsInsetRect(CGRectMake(columnMetrics.offset, header_y, columnMetrics.width, self.headerHeight), self.headerViewInsets);
            header.zIndex = ColumnHeaderView_zIndex;
            [array addObject:header];
#endif
        }
    }
#endif
    
    NSArray *columns = section.columnMetrics;
    const UIEdgeInsets cellViewInsets = self.cellViewInsets;
    
    LJCollectionViewTableLayoutTablePosition p;
    for (p.row = firstRow; p.row <= lastRow; ++p.row) {
        const CGFloat row_y = _headerHeight + (p.row * row_height);
        
        for (p.column = column_range.location; p.column < NSMaxRange(column_range); ++p.column) {
            LJCollectionViewTableColumnMetrics *columnMetrics = columns[p.column];
            NSIndexPath *indexPath = [section indexPathForTablePosition:p];
            UICollectionViewLayoutAttributes *cell = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            cell.frame = UIEdgeInsetsInsetRect(CGRectMake(columnMetrics.offset, row_y, columnMetrics.width, _rowHeight), cellViewInsets);
            cell.zIndex = Cell_zIndex;
            [array addObject:cell];
        }
#if (SHOW_ROW_BG)
        LJCollectionViewTableLayoutRowViewAttributes *row = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindRowBackground withIndexPath:[NSIndexPath indexPathForItem:p.row inSection:sectionIndex]];
        row.frame = CGRectMake(0, row_y, section.totalWidthOfAllColumns, _rowHeight);
        row.zIndex = RowBackground_zIndex;
        row.backgroundColor = [self backgroundColorForItemOnRowAtIndex:p.row];
        [array addObject:row];
#endif
    }
    
#if (SHOW_SEPARATORS)
    [array addObject:section.tableBackgroundAttributes];
    
#if (CACHE_COLUMN_SEPARATOR_ATTRIBUTES)
    for (NSInteger column_i = column_range.location; column_i < NSMaxRange(column_range); ++column_i) {
        [array addObject:section.columnSeparatorAttributes[column_i]];
    }
#else
    {
        const CGFloat header_y = [self contentOffsetForFloatingAtTopOfSection:section];
        const CGFloat height = self.collectionView.bounds.size.height;
        
        for (NSInteger column_i = column_range.location; column_i < NSMaxRange(column_range); ++column_i) {
            LJCollectionViewTableColumnMetrics *columnMetrics = section.columnMetrics[column_i];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:column_i inSection:sectionIndex];
            LJCollectionViewTableLayoutColumnSeparatorsViewAttributes *separator = [LJCollectionViewTableLayoutColumnSeparatorsViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnSeparators withIndexPath:indexPath];
            separator.frame = CGRectMake(columnMetrics.offset + columnMetrics.width, header_y, self.columnSeparatorWidth, height);
            separator.zIndex = ColumnSeparators_zIndex;
            separator.separatorColor = self.columnSeparatorColor;
            [array addObject:separator];
        }
    }
#endif
    
#endif
    
    return array.count - count_at_start;
}



- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    DbgDetailLog(@"%@", indexPath);
    LJCollectionViewTableSection *section = self.sections[indexPath.section];
    LJCollectionViewTableLayoutTablePosition p = [self tablePositionForIndexPath:indexPath];
    LJCollectionViewTableColumnMetrics *columnMetrics = section.columnMetrics[p.column];
    const CGFloat row_y = _headerHeight + (p.row * (_rowHeight + _rowSeparatorWidth));
    UICollectionViewLayoutAttributes *cell = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    cell.frame = UIEdgeInsetsInsetRect(CGRectMake(columnMetrics.offset, row_y, columnMetrics.width, _rowHeight), _cellViewInsets);
    cell.zIndex = Cell_zIndex;
    return cell;
}



- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    LJCollectionViewTableSection *section = self.sections[0];
    
    if (kind == LJCollectionViewTableLayoutElementKindColumnHeader) {
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
        UICollectionViewLayoutAttributes *header = section.headerAttributes[indexPath.item];
        return header;
#else
        const CGFloat header_y = (self.shouldFloatHeader) ? [self contentOffsetForFloatingAtTopOfSection:section] : 0;
        const NSInteger column_i = indexPath.item;
        LJCollectionViewTableColumnMetrics *columnMetrics = section.columnMetrics[column_i];
        UICollectionViewLayoutAttributes *header = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeader withIndexPath:indexPath];
        header.frame = UIEdgeInsetsInsetRect(CGRectMake(columnMetrics.offset, header_y, columnMetrics.width, self.headerHeight), self.headerViewInsets);
        header.zIndex = ColumnHeaderView_zIndex;
        
        return header;
#endif
    }
    
    else
        return [super layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
}



- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    LJCollectionViewTableSection *section = self.sections[0];
    
    if (kind == LJCollectionViewTableLayoutElementKindTableBackground) {
        return section.tableBackgroundAttributes;
    }
    
    else if (kind == LJCollectionViewTableLayoutElementKindColumnSeparators) {
#if (CACHE_COLUMN_SEPARATOR_ATTRIBUTES)
        UICollectionViewLayoutAttributes *separator = section.columnSeparatorAttributes[indexPath.item];
        return separator;
#else
        UICollectionView *cv = self.collectionView;
        const CGFloat contentOffset = cv.contentOffset.y, contentInset = cv.contentInset.top;
        CGFloat header_y = MIN( MAX(contentOffset+contentInset,0), section.numberOfRows * self.rowHeight), height = cv.bounds.size.height;
        
        const NSInteger column_i = indexPath.item;
        LJCollectionViewTableColumnMetrics *columnMetrics = section.columnMetrics[column_i];
        LJCollectionViewTableLayoutColumnSeparatorsViewAttributes *separator = [LJCollectionViewTableLayoutColumnSeparatorsViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnSeparators withIndexPath:indexPath];
        separator.frame = CGRectMake(columnMetrics.offset + columnMetrics.width, header_y, self.columnSeparatorWidth, height);
        separator.zIndex = ColumnSeparators_zIndex;
        separator.separatorColor = self.columnSeparatorColor;
        return separator;
#endif
    }
    
    else if (kind == LJCollectionViewTableLayoutElementKindColumnHeaderBackground) {
#if (CACHE_HEADER_LAYOUT_ATTRIBUTES)
        return section.headerBackgroundAttributes;
#else
        const CGFloat header_y = (self.shouldFloatHeader) ? [self contentOffsetForFloatingAtTopOfSection:section] : 0;
        LJCollectionViewTableLayoutRowViewAttributes *header_background = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeaderBackground withIndexPath:indexPath];
        header_background.frame = CGRectMake(0, header_y, section.totalWidthOfAllColumns, self.headerHeight);
        header_background.zIndex = HeaderBackground_zIndex;
        header_background.backgroundColor = self.headerBackgroundColor;
        
        return header_background;
#endif
    }
    
    else if (kind == LJCollectionViewTableLayoutElementKindRowBackground) {
        const NSInteger rowIndex = indexPath.item;
        const CGFloat row_y = _headerHeight + (rowIndex * (_rowHeight + _rowSeparatorWidth));
        LJCollectionViewTableLayoutRowViewAttributes *row = [LJCollectionViewTableLayoutRowViewAttributes layoutAttributesForDecorationViewOfKind:LJCollectionViewTableLayoutElementKindRowBackground withIndexPath:[NSIndexPath indexPathForItem:rowIndex inSection:indexPath.section]];
        row.frame = CGRectMake(0, row_y, section.totalWidthOfAllColumns, _rowHeight);
        row.zIndex = RowBackground_zIndex;
        row.backgroundColor = [self backgroundColorForItemOnRowAtIndex:rowIndex];
        return row;
    }
    
    else
        return [super layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath];
}





#pragma mark - TablePosition index conversions

- (LJCollectionViewTableLayoutTablePosition)tablePositionForIndexPath:(NSIndexPath *)indexPath {
    LJCollectionViewTableSection *section = self.sections[indexPath.section];
    const NSInteger numberOfColumns = section.numberOfColumns;
    
    LJCollectionViewTableLayoutTablePosition tablePosition;
    tablePosition.row = indexPath.item / numberOfColumns;
    tablePosition.column = indexPath.item - (tablePosition.row * numberOfColumns);
    return tablePosition;
}

- (LJCollectionViewTableLayoutTablePosition)tablePositionForItemIndex:(NSInteger)item inSection:(NSInteger)sectionIndex {
    LJCollectionViewTableSection *section = self.sections[sectionIndex];
    const NSInteger numberOfColumns = section.numberOfColumns;
    
    LJCollectionViewTableLayoutTablePosition tablePosition;
    tablePosition.row = item / numberOfColumns;
    tablePosition.column = item - (tablePosition.row * numberOfColumns);
    return tablePosition;
}



+ (NSInteger)numberOfItemsForTableWithColumnCount:(NSInteger)numberOfColumns rowCount:(NSInteger)numberOfRows {
    return numberOfColumns * numberOfRows;
}




#pragma mark - misc

- (UIColor *)backgroundColorForItemAtIndexPath:(NSIndexPath *)indexPath {
    LJCollectionViewTableLayoutTablePosition p = [self tablePositionForIndexPath:indexPath];
    return [self backgroundColorForItemOnRowAtIndex:p.row];
}

- (UIColor *)backgroundColorForItemOnRowAtIndex:(NSInteger)rowIndex {
    return ((rowIndex+1) & 1)
    ? self.oddRowBackgroundColor
    : self.evenRowBackgroundColor;
}



- (CGFloat)contentOffsetForFloatingAtTopOfSection:(LJCollectionViewTableSection *)section {
    UICollectionView *cv = self.collectionView;
    const CGFloat contentOffset = cv.contentOffset.y, contentInset = cv.contentInset.top;
    return MIN( MAX(contentOffset+contentInset,0), section.numberOfRows * self.rowHeight);
}

@end





@implementation LJCollectionViewTableSection

- (NSRange)columnsCoveredByRect:(CGRect)rect {
    CGFloat min_x = CGRectGetMinX (rect), max_x = CGRectGetMaxX (rect);
    NSRange range = {NSNotFound,0};
    
    if (max_x < 0)
        return range;
    
    NSInteger col_i = 0;
    for (LJCollectionViewTableColumnMetrics *metrics in _columnMetrics) {
        if ((metrics.offset + metrics.width) < min_x)
            ++col_i;
        else {
            range.location = col_i;
            range.length = 1;
            break;
        }
    }
    
    if (range.location == NSNotFound)
        return range;
    
    NSInteger col_end = _columnMetrics.count-1;
    for (col_i=range.location+1; col_i <= col_end; ++col_i) {
        LJCollectionViewTableColumnMetrics *metrics = _columnMetrics[col_i];
        if (metrics.offset > max_x)
            break;
        else
            ++range.length;
    }
    
    return range;
}



- (NSInteger)itemIndexForTablePosition:(LJCollectionViewTableLayoutTablePosition)tablePosition {
    return (tablePosition.row * _numberOfColumns) + tablePosition.column;
}

- (NSIndexPath *)indexPathForTablePosition:(LJCollectionViewTableLayoutTablePosition)tablePosition {
    return [NSIndexPath indexPathForItem:(tablePosition.row * _numberOfColumns) + tablePosition.column
                               inSection:_index];
}

@end





@implementation LJCollectionViewTableLayoutRowBackgroundView

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    if ([layoutAttributes respondsToSelector:@selector(backgroundColor)])
        self.backgroundColor = [(LJCollectionViewTableLayoutRowViewAttributes *)layoutAttributes backgroundColor];
    
    else if (layoutAttributes.representedElementKind == LJCollectionViewTableLayoutElementKindColumnHeaderBackground) {
        if ([layoutAttributes isKindOfClass:[LJCollectionViewTableLayoutRowViewAttributes class]])
            self.backgroundColor = [(LJCollectionViewTableLayoutRowViewAttributes *)layoutAttributes backgroundColor];
        else
            self.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
    }
    
    else if (layoutAttributes.representedElementKind == LJCollectionViewTableLayoutElementKindRowBackground) {
        if ([layoutAttributes isKindOfClass:[LJCollectionViewTableLayoutRowViewAttributes class]])
            self.backgroundColor = [(LJCollectionViewTableLayoutRowViewAttributes *)layoutAttributes backgroundColor];
        else
            self.backgroundColor = (layoutAttributes.indexPath.item & 1)
            ? [UIColor colorWithWhite:1 alpha:1]
            : [UIColor colorWithWhite:0.98 alpha:1];
    }
    
    else
        [super applyLayoutAttributes:layoutAttributes];
}

@end





@implementation LJCollectionViewTableLayoutColumnSeparatorsView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    
    if ([layoutAttributes respondsToSelector:@selector(separatorColor)])
        self.backgroundColor = [(LJCollectionViewTableLayoutColumnSeparatorsViewAttributes *)layoutAttributes separatorColor];
    else
        [super applyLayoutAttributes:layoutAttributes];
}

@end





#if (USE_INVALIDATION_CONTEXT)
@implementation LJCollectionViewTableLayoutInvalidationContext

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (NSString *)description {
    return [NSString stringWithFormat:@"{invalidateDataSourceCounts=%d, invalidateEverything=%d, invalidateFloatingViews=%d}",
            self.invalidateDataSourceCounts, self.invalidateEverything,
            self.invalidateFloatingViews];
}

@end
#endif





inline CGFloat CGFloatCeil(CGFloat value) {
#if CGFLOAT_IS_DOUBLE
    return ceil(value);
#else
    return ceilf(value);
#endif
}

inline CGFloat CGFloatFloor(CGFloat value) {
#if CGFLOAT_IS_DOUBLE
    return floor(value);
#else
    return floorf(value);
#endif
}
