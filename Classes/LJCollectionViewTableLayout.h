//
//  LJCollectionViewTableLayout.h
//  Simply SQL iOS
//
//  Created by Logan Jones on 9/3/13.
//  Copyright (c) 2013 Toasty. All rights reserved.
//

#import <UIKit/UIKit.h>


UIKIT_EXTERN NSString *const LJCollectionViewTableLayoutElementKindColumnHeader;
UIKIT_EXTERN NSString *const LJCollectionViewTableLayoutElementKindColumnHeaderBackground;
UIKIT_EXTERN NSString *const LJCollectionViewTableLayoutElementKindRowBackground;


/*! @typedef LJCollectionViewTableLayoutTablePosition
    @field row Zero-based index that addresses a distinct row in a table.
    @field column Zero-based index that addresses a distinct column in a table.
    @discussion A cell/item in a LJCollectionViewTableLayout is uniquely addressed by its row & column position.
 */
typedef struct {
    NSInteger column, row;
} LJCollectionViewTableLayoutTablePosition;





/*! Extends UICollectionViewDataSource to provide extra information about
    the structure of the table's data. All of these methods are optional
    and if not defined in an implementing class then a suitable defualt
    in LJCollectionViewTableLayout will be used instead.
 */
@protocol LJCollectionViewDataSourceTableLayout <UICollectionViewDataSource>
@optional


/*! Asks the data source for the number of columns in the table of the specified section.
    If this method is not implemented in the data source then the value retured by 
    [collectionView numberOfColumns] will be used instead.
 */
- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout numberOfColumnsForTableInSection:(NSInteger)section;


/*! Asks the data source for the number of rows in the table of the specified section.
 If this method is not implemented in the data source then the value retured by
 [collectionView numberOfRows] will be used instead.
 */
- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout numberOfRowsForTableInSection:(NSInteger)section;

@end





/*! Extends UICollectionViewDelegate ot provide additional information about the layout of the table's data.
 */
@protocol LJCollectionViewDelegateTableLayout <UICollectionViewDelegate>
@optional


/*! Asks for the width (in points) of a specific column in a data table.
    Return a value of 0 to force the use of the default ([collectionView columnWidth]) for this column.
    If this method remains unimplemented then all columns will use the default value returned by [collectionView columnWidth].
 */
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout widthOfColumn:(NSInteger)column forTableInSection:(NSInteger)section;


//- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout numberOfAccessoryRowsForTableInSection:(NSInteger)section;
//
//- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout positionOfAccessoryRowAtIndex:(NSInteger)rowIndex forTableInSection:(NSInteger)section;
//
//- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout heightOfAccessoryRowAtIndex:(NSInteger)rowIndex forTableInSection:(NSInteger)section;

@end





/*! Extends UICollectionViewLayout to provide a tabular (row & columns) layout for UICollectionView.
 */
@interface LJCollectionViewTableLayout : UICollectionViewLayout


// Reference value properties for various table layout attributes.
// (Some of these values may be overridden by the UICollectionView delegate. See LJCollectionViewDelegateTableLayout)


/*! Reference value for the number of rows in this table layout.
    This can be overridden by the delegate's collectionView:layout:numberOfRowsForTableInSection: method.
 */
@property (nonatomic) NSInteger numberOfRows;


/*! Reference value for the number of columns in this table layout.
    This can be overridden by the delegate's collectionView:layout:numberOfColumnsForTableInSection: method.
 */
@property (nonatomic) NSInteger numberOfColumns;


/*! Reference value for the height of each data row in this table layout.
 */
@property (nonatomic) CGFloat rowHeight;


/*! Reference value for the width of each column in this table layout.
    This can be overridden by the delegate's collectionView:layout:widthOfColumn:forTableInSection: method.
 */
@property (nonatomic) CGFloat columnWidth;


/*! Reference value for the height of the header row in this table layout.
 */
@property (nonatomic) CGFloat headerHeight;


/*! If YES, then the table header row will 'float' and stay visible as the view is scrolled.
    If NO, then the header appears as the first row and scrolls offscreen just as every other normal row.
 */
@property (nonatomic) BOOL shouldFloatHeader;


/*! The size (in points) of the divider lines in the table.
 */
@property (nonatomic) CGFloat columnSeparatorWidth, rowSeparatorWidth;


/*! The color of the divider lines in the table.
 */
@property (nonatomic, retain) UIColor *columnSeparatorColor, *rowSeparatorColor;


/*! The bounds rect for each cell can be further contrained by giving it an inset.
    The default inset is UIEdgeInsetsZero; this mkaes the edge of every cell run flush
    with the row & column dividers.
 */
@property (nonatomic) UIEdgeInsets cellViewInsets, headerViewInsets;


/*! The background color of a row.
 */
@property (nonatomic, retain) UIColor *headerBackgroundColor, *oddRowBackgroundColor, *evenRowBackgroundColor;



/*! Converts the indexPath given in many collectionView methods to a table position (row & column index).
 */
- (LJCollectionViewTableLayoutTablePosition)tablePositionForIndexPath:(NSIndexPath *)indexPath;
- (LJCollectionViewTableLayoutTablePosition)tablePositionForItemIndex:(NSInteger)item inSection:(NSInteger)section;


/*! Convenience method for calculating the total item/cell count based on the number of rows and columns.
    This is useful for the dataSource's collectionView:numberOfItemsInSection: method.
 */
+ (NSInteger)numberOfItemsForTableWithColumnCount:(NSInteger)numberOfColumns rowCount:(NSInteger)numberOfRows;


/*! Convenience method for determining the background color for and specific table item.
    This is usually dependent on what row the item is on.
 */
- (UIColor *)backgroundColorForItemAtIndexPath:(NSIndexPath *)indexPath;
- (UIColor *)backgroundColorForItemOnRowAtIndex:(NSInteger)rowIndex;

@end
