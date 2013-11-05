//
//  ViewController.m
//  Example
//
//  Created by Logan Jones on 9/15/13.
//  Copyright (c) 2013 Logan Jones. All rights reserved.
//

#import "ViewController.h"
#import "LJCollectionViewTableLayout.h"
#import "TableDataSource.h"

@interface ViewController () <UICollectionViewDataSource, LJCollectionViewDataSourceTableLayout, LJCollectionViewDelegateTableLayout>
@property (nonatomic, strong) TableDataSource *data;
@property (nonatomic, weak) UICollectionView *collection;
@end

// Completely opaque are generally more performant; but not overwhelmingly so for this simple example.
#define OPAQUE_CELLS    0

// Put the data loading into a delay to simulate a longer loading time.
#define SIMULATE_LOAD_TIME  0

// Change this to 1 for an example of a larger dataset.
#define STRESS_TEST     0
#if (STRESS_TEST)
const NSInteger ColumnsMultiplier = 10;
const NSInteger RowsMultiplier = 1000;
#endif





@implementation ViewController


#pragma mark - View lifecycle

- (void)loadView {
    UIView *main = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 256, 256)];
    main.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    
    LJCollectionViewTableLayout *layout = [LJCollectionViewTableLayout new];
    layout.headerHeight = 44;
    layout.rowHeight = 44;
    layout.columnWidth = 200;
    layout.cellViewInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    layout.headerViewInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    //layout.shouldFloatHeader = NO;
    
    UICollectionView *collection = [[UICollectionView alloc] initWithFrame:main.bounds
                                                      collectionViewLayout:layout];
    collection.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    collection.dataSource = self;
    collection.delegate = self;
    [collection registerNib:[UINib nibWithNibName:@"DataCell" bundle:nil]
 forCellWithReuseIdentifier:@"DataCell"];
    [collection registerNib:[UINib nibWithNibName:@"HeaderView" bundle:nil]
 forSupplementaryViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeader
        withReuseIdentifier:@"HeaderView"];
    [main addSubview:collection];
    self.collection = collection;
    
    collection.backgroundColor = layout.oddRowBackgroundColor;
    
    self.view = main;
}

 

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"world" ofType:@"csv"];
    self.title = [path lastPathComponent];
    
#if (SIMULATE_LOAD_TIME)
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
#endif
        
        self.data = [TableDataSource newWithCsvFileAtPath:path];
        [self.collection reloadData];
        
#if (SIMULATE_LOAD_TIME)
    });
#endif
}



- (void)viewDidLayoutSubviews {
    if ([self respondsToSelector:@selector(topLayoutGuide)]) {
        self.collection.contentInset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 0, 0);
    }
}





#pragma mark - UICollectionViewDataSource

#if (!STRESS_TEST) // Normal path

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [LJCollectionViewTableLayout numberOfItemsForTableWithColumnCount:self.data.numberOfColumns
                                                                    rowCount:self.data.numberOfRows];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout numberOfRowsForTableInSection:(NSInteger)section {
    return self.data.numberOfRows;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout numberOfColumnsForTableInSection:(NSInteger)section {
    return self.data.numberOfColumns;
}

#endif



- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LJCollectionViewTableLayoutTablePosition p = [(LJCollectionViewTableLayout *)self.collection.collectionViewLayout tablePositionForIndexPath:indexPath];
    
#if (STRESS_TEST)
    // De-multiply the table position. This is only applicable for the stress test and can/should be ignored.
    p = [self actualPositionForMultipliedPosition:p];
#endif
    
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"DataCell" forIndexPath:indexPath];
    
    UILabel *label = (UILabel *)[cell viewWithTag:1];
    label.text = [self.data stringInRow:p.row andColumn:p.column];
    
    
#if (OPAQUE_CELLS)
    cell.opaque = YES;
    label.opaque = YES;
    UIColor *color = [(LJCollectionViewTableLayout *)self.collection.collectionViewLayout backgroundColorForItemOnRowAtIndex:p.row];
    cell.backgroundColor = color;
    label.backgroundColor = color;
#endif
    
    return cell;
    
}



- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind ==LJCollectionViewTableLayoutElementKindColumnHeader) {
        UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:LJCollectionViewTableLayoutElementKindColumnHeader withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
        
        UILabel *label = (UILabel *)[header viewWithTag:1];
        label.text = [self.data nameOfColumnAtIndex:indexPath.item % self.data.numberOfColumns];
        
#if (OPAQUE_CELLS)
        LJCollectionViewTableLayout *layout = (LJCollectionViewTableLayout *)self.collection.collectionViewLayout;
        header.opaque = YES;
        label.opaque = YES;
        header.backgroundColor = layout.headerBackgroundColor;
        label.backgroundColor = layout.headerBackgroundColor;
#endif
        
        return header;
    }
    
    return nil;
}





#pragma mark - LJCollectionViewDelegateTableLayout

//- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout widthOfColumn:(NSInteger)column inSection:(NSInteger)section {
//    QueryRowSetDisplayColumnMetrics *metrics = self.configuration.columnMetrics[column];
//    return metrics.width;
//}





#pragma mark - UICollectionViewDataSource (Stress Test)

#if (STRESS_TEST) // Do the stress test
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [LJCollectionViewTableLayout numberOfItemsForTableWithColumnCount:self.data.numberOfColumns * ColumnsMultiplier
                                                                    rowCount:self.data.numberOfRows * RowsMultiplier];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout numberOfRowsForTableInSection:(NSInteger)section {
    return self.data.numberOfRows * RowsMultiplier;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout numberOfColumnsForTableInSection:(NSInteger)section {
    return self.data.numberOfColumns * ColumnsMultiplier;
}
#endif





#pragma mark - Misc

#if (STRESS_TEST)
- (LJCollectionViewTableLayoutTablePosition)actualPositionForMultipliedPosition:(LJCollectionViewTableLayoutTablePosition)p {
    p.column %= self.data.numberOfColumns;
    p.row %= self.data.numberOfRows;
    return p;
}
#endif

@end
