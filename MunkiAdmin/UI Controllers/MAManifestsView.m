//
//  MAManifestsView.m
//  MunkiAdmin
//
//  Created by Hannes Juutilainen on 6.3.2015.
//
//

#import "MAManifestsView.h"
#import "MAManifestsViewSourceListItem.h"
#import "DataModelHeaders.h"
#import "MAMunkiAdmin_AppDelegate.h"
#import "MAMunkiRepositoryManager.h"
#import "MACoreDataManager.h"
#import "CocoaLumberjack.h"
#import "MAManifestEditor.h"

DDLogLevel ddLogLevel;

#define kMinSplitViewWidth      200.0f
#define kMaxSplitViewWidth      400.0f
#define kDefaultSplitViewWidth  300.0f
#define kMinSplitViewHeight     80.0f
#define kMaxSplitViewHeight     400.0f

#define DEFAULT_PREDICATE @"title contains[cd] ''"

@interface MAManifestsView ()
@property (strong, nonatomic) NSMutableArray *modelObjects;
@property (strong, nonatomic) NSMutableArray *sourceListItems;
@end

@implementation MAManifestsView

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
}

- (MAManifestEditor *)editorForManifest:(ManifestMO *)manifest
{
    MAManifestEditor *existingEditor = [self.openedManifestEditors objectForKey:manifest.objectID.description];
    if (!existingEditor) {
        MAManifestEditor *newEditor = [[MAManifestEditor alloc] initWithWindowNibName:@"MAManifestEditor"];
        newEditor.manifestToEdit = manifest;
        newEditor.delegate = self;
        [self.openedManifestEditors setObject:newEditor forKey:manifest.objectID.description];
        
        return newEditor;
    } else {
        return existingEditor;
    }
}

- (void)openEditorForManifest:(ManifestMO *)manifest
{
    MAManifestEditor *editor = [self editorForManifest:manifest];
    [editor showWindow:nil];
}

- (void)didDoubleClickManifest:(id)sender
{
    for (ManifestMO *manifest in [self.manifestsArrayController selectedObjects]) {
        DDLogVerbose(@"%@: %@", NSStringFromSelector(_cmd), manifest.title);
        [self openEditorForManifest:manifest];
    }
}

- (void)rowsChanged:(NSNotification *)aNotification
{
    [self uncollapseFindView];
    [self updateSearchPredicateFromEditor];
}

- (void)searchUpdated:(NSNotification *)aNotification
{
    [self updateSearchPredicateFromEditor];
}

- (void)updateSearchPredicateFromEditor
{
    DDLogVerbose(@"%@", [[self.manifestsListPredicateEditor predicate] description]);
    if ([[self.manifestsListPredicateEditor predicate] isEqualTo:[NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:DEFAULT_PREDICATE]]]]) {
        //DDLogVerbose(@"EQUAL: %@", [[self.manifestsListPredicateEditor predicate] description]);
        self.searchFieldPredicate = [NSPredicate predicateWithValue:YES];
    } else {
        self.searchFieldPredicate = [self.manifestsListPredicateEditor predicate];
    }
}

- (void)resetSearch
{
    self.previousPredicateEditorPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:DEFAULT_PREDICATE]]];
    self.manifestsListPredicateEditor.objectValue = self.previousPredicateEditorPredicate;
    
    [self searchUpdated:nil];
    
    [self.view.window makeFirstResponder:self.manifestsListPredicateEditor];
    [self.view.window selectKeyViewFollowingView:self.manifestsListPredicateEditor];
    [self.view.window recalculateKeyViewLoop];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    /*
     Update the mainCompoundPredicate everytime the subcomponents are updated
     */
    if ([key isEqualToString:@"mainCompoundPredicate"])
    {
        NSSet *affectingKeys = [NSSet setWithObjects:@"selectedSourceListFilterPredicate", @"searchFieldPredicate", nil];
        keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
    }
    
    return keyPaths;
}


- (NSPredicate *)mainCompoundPredicate
{
    /*
     Combine the selected source list item predicate and the possible search predicate
     */
    return [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:self.selectedSourceListFilterPredicate, self.searchFieldPredicate, nil]];
}

- (void)awakeFromNib
{
    //[self.sourceList registerForDraggedTypes:@[draggingType]];
    
    [self setDetailView:self.manifestsListView];
    
    
    self.manifestEditor = [[MAManifestEditor alloc] initWithWindowNibName:@"MAManifestEditor"];
    self.openedManifestEditors = [NSMutableDictionary new];
    
    self.predicateEditorHidden = YES;
    self.searchFieldPredicate = [NSPredicate predicateWithValue:YES];
    self.selectedSourceListFilterPredicate = [NSPredicate predicateWithValue:YES];
    self.previousPredicateEditorPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:DEFAULT_PREDICATE]]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchUpdated:) name:NSControlTextDidChangeNotification object:self.manifestsListPredicateEditor];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rowsChanged:) name:NSRuleEditorRowsDidChangeNotification object:self.manifestsListPredicateEditor];
    
    NSMutableArray *rowTemplates = [[self.manifestsListPredicateEditor rowTemplates] mutableCopy];
    
    /*
     String types row template
     */
    NSArray *containsOperator = @[@(NSContainsPredicateOperatorType)];
    NSArray *leftExpressions = @[
                                 [NSExpression expressionForKeyPath:@"allPackageStrings"],
                                 [NSExpression expressionForKeyPath:@"catalogStrings"],
                                 [NSExpression expressionForKeyPath:@"managedInstallsStrings"],
                                 [NSExpression expressionForKeyPath:@"managedUninstallsStrings"],
                                 [NSExpression expressionForKeyPath:@"managedUpdatesStrings"],
                                 [NSExpression expressionForKeyPath:@"optionalInstallsStrings"],
                                 [NSExpression expressionForKeyPath:@"includedManifestsStrings"],
                                 [NSExpression expressionForKeyPath:@"referencingManifestsStrings"],
                                 [NSExpression expressionForKeyPath:@"conditionalItemsStrings"],
                                 ];
    NSPredicateEditorRowTemplate *catalogsTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:leftExpressions
                                                                                      rightExpressionAttributeType:NSStringAttributeType
                                                                                                          modifier:NSAnyPredicateModifier
                                                                                                         operators:containsOperator
                                                                                                           options:(NSCaseInsensitivePredicateOption | NSDiacriticInsensitivePredicateOption)];
    [rowTemplates addObject:catalogsTemplate];
    
    /*
     Add the row templates to the predicate editor
     */
    [self.manifestsListPredicateEditor setRowTemplates:rowTemplates];
    
    NSDictionary *formatting = @{
                                 @"%[title]@ %[contains]@ %@" : @"%[Name]@ %[contains]@ %@",
                                 @"%[allPackageStrings]@ %[contains]@ %@" : @"%[Any installs item]@ %[contains]@ %@",
                                 @"%[fileName]@ %[contains]@ %@" : @"%[Filename]@ %[contains]@ %@",
                                 @"%[catalogStrings]@ %[contains]@ %@" : @"%[Catalogs]@ %[contains]@ %@",
                                 @"%[managedInstallsStrings]@ %[contains]@ %@" : @"%[Managed installs]@ %[contains]@ %@",
                                 @"%[managedUninstallsStrings]@ %[contains]@ %@" : @"%[Managed uninstalls]@ %[contains]@ %@",
                                 @"%[managedUpdatesStrings]@ %[contains]@ %@" : @"%[Managed updates]@ %[contains]@ %@",
                                 @"%[optionalInstallsStrings]@ %[contains]@ %@" : @"%[Optional installs]@ %[contains]@ %@",
                                 @"%[includedManifestsStrings]@ %[contains]@ %@" : @"%[Included manifests]@ %[contains]@ %@",
                                 @"%[referencingManifestsStrings]@ %[contains]@ %@" : @"%[Referencing manifests]@ %[contains]@ %@",
                                 @"%[conditionalItemsStrings]@ %[contains]@ %@" : @"%[Condition predicates]@ %[contains]@ %@",
                                 };
    [self.manifestsListPredicateEditor setFormattingDictionary:formatting];
    
    [self updateSourceListData];
    
    [self.manifestsListTableView setTarget:self];
    [self.manifestsListTableView setDoubleAction:@selector(didDoubleClickManifest:)];
    [self.manifestsListTableView setMenu:self.manifestsListMenu];
}

- (void)updateSourceListData
{
    [self configureSourceList];
    [self configureSplitView];
    self.sourceListItems = [[NSMutableArray alloc] init];
    
    [self setUpDataModel];
    self.defaultSortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedStandardCompare:)]];
    self.manifestsArrayController.sortDescriptors = self.defaultSortDescriptors;
    
    [self.sourceList reloadData];
    [self.sourceList expandItem:nil expandChildren:YES];
    [self.sourceList selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
    [self.sourceList setNeedsDisplay:YES];
}

- (void)configureSourceList
{
    [self.sourceList sizeLastColumnToFit];
    [self.sourceList setFloatsGroupRows:NO];
    [self.sourceList setRowSizeStyle:NSTableViewRowSizeStyleDefault];
    [self.sourceList setIndentationMarkerFollowsCell:YES];
    [self.sourceList setIndentationPerLevel:14];
}

- (void)configureSplitView
{
    [self.mainSplitView setDividerStyle:NSSplitViewDividerStyleThin];
}

# pragma mark -
# pragma mark IBActions

- (IBAction)resetSearchAction:(id)sender
{
    [self resetSearch];
}

# pragma mark - 
# pragma mark Data Model

- (void)setUpDataModel
{
    /*
     Predicates
     */
    NSPredicate *noReferencingManifests     = [NSPredicate predicateWithFormat:@"referencingManifests.@count = 0"];
    NSPredicate *hasReferencingManifests    = [NSPredicate predicateWithFormat:@"referencingManifests.@count > 0"];
    NSPredicate *hasIncludedManifests       = [NSPredicate predicateWithFormat:@"includedManifestsFaster.@count > 0 OR (SUBQUERY(conditionalItems, $x, $x.includedManifests.@count > 0).@count != 0)"];
    NSPredicate *noIncludedManifests        = [NSPredicate predicateWithFormat:@"(includedManifestsFaster.@count == 0) AND (SUBQUERY(conditionalItems, $x, $x.includedManifests.@count > 0).@count == 0)"];
    
    //NSPredicate *noManagedInstalls        = [NSPredicate predicateWithFormat:@"allManagedInstalls.@count == 0"];
    NSPredicate *hasManagedInstalls         = [NSPredicate predicateWithFormat:@"(managedInstallsFaster.@count > 0) OR (SUBQUERY(conditionalItems, $x, $x.managedInstalls.@count > 0).@count != 0)"];
    
    //NSPredicate *noManagedUninstalls      = [NSPredicate predicateWithFormat:@"allManagedUninstalls.@count == 0"];
    NSPredicate *hasManagedUninstalls       = [NSPredicate predicateWithFormat:@"(managedUninstallsFaster.@count > 0) OR (SUBQUERY(conditionalItems, $x, $x.managedUninstalls.@count > 0).@count != 0)"];
    
    //NSPredicate *noOptionalInstalls       = [NSPredicate predicateWithFormat:@"allOptionalInstalls.@count == 0"];
    NSPredicate *hasOptionalInstalls        = [NSPredicate predicateWithFormat:@"(optionalInstallsFaster.@count > 0) OR (SUBQUERY(conditionalItems, $x, $x.optionalInstalls.@count > 0).@count != 0)"];
    
    //NSPredicate *noManagedUpdates         = [NSPredicate predicateWithFormat:@"allManagedUpdates.@count == 0"];
    NSPredicate *hasManagedUpdates          = [NSPredicate predicateWithFormat:@"(managedUpdatesFaster.@count > 0) OR (SUBQUERY(conditionalItems, $x, $x.managedUpdates.@count > 0).@count != 0)"];
    
    /*
     All Manifests item
     */
    MAManifestsViewSourceListItem *allManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:@"All Manifests" identifier:@"allManifests" type:ManifestSourceItemTypeFolder];
    allManifestsItem.filterPredicate = [NSPredicate predicateWithValue:TRUE];
    
    /*
     Recently modified item
     */
    MAManifestsViewSourceListItem *recentlyModifiedItem = [MAManifestsViewSourceListItem collectionWithTitle:@"Recently Modified" identifier:@"recentlyModified" type:ManifestSourceItemTypeFolder];
    NSDate *now = [NSDate date];
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    dayComponent.day = -7;
    NSDate *sevenDaysAgo = [[NSCalendar currentCalendar] dateByAddingComponents:dayComponent toDate:now options:0];
    NSPredicate *recentlyModifiedPredicate = [NSPredicate predicateWithFormat:@"manifestDateModified >= %@", sevenDaysAgo];
    recentlyModifiedItem.filterPredicate = recentlyModifiedPredicate;
    
    /*
     Machine manifests item
     */
    MAManifestsViewSourceListItem *machineManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:@"Machine Manifests" identifier:@"machineManifests" type:ManifestSourceItemTypeFolder];
    machineManifestsItem.filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[noReferencingManifests, hasIncludedManifests]];
    
    /*
     Group manifests item
     */
    MAManifestsViewSourceListItem *groupManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:@"Group Manifests" identifier:@"groupManifests" type:ManifestSourceItemTypeFolder];
    groupManifestsItem.filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[hasReferencingManifests, hasIncludedManifests]];
    
    /*
     Profile manifests item
     */
    MAManifestsViewSourceListItem *profileManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:@"Profile Manifests" identifier:@"profileManifests" type:ManifestSourceItemTypeFolder];
    profileManifestsItem.filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[
                                                [NSCompoundPredicate andPredicateWithSubpredicates:@[hasReferencingManifests, noIncludedManifests]],
                                                [NSCompoundPredicate orPredicateWithSubpredicates:@[hasManagedInstalls, hasManagedUninstalls, hasManagedUpdates, hasOptionalInstalls]]
                                                ]];
    
    /*
     Self-contained manifests item
     */
    /*
    MAManifestsViewSourceListItem *selfContainedManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:@"Self-contained Manifests" identifier:@"selfContainedManifests" type:ManifestSourceItemTypeFolder];
    selfContainedManifestsItem.filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[noReferencingManifests, noIncludedManifests]];
     */
    
    // Icon images we're going to use in the Source List.
    
    NSImage *notepad = [NSImage imageNamed:@"book"];
    [notepad setTemplate:YES];
    
    NSImage *inbox = [NSImage imageNamed:@"inbox"];
    [inbox setTemplate:YES];
    
    NSImage *calendar = [NSImage imageNamed:@"calendar_ok"];
    [calendar setTemplate:YES];
    
    NSImage *folder = [NSImage imageNamed:@"folder"];
    [folder setTemplate:YES];
    
    NSImage *document = [NSImage imageNamed:@"document"];
    [document setTemplate:YES];
    
    NSImage *documents = [NSImage imageNamed:@"documents"];
    [documents setTemplate:YES];
    
    NSImage *documentDownload = [NSImage imageNamed:@"document_download"];
    [documentDownload setTemplate:YES];
    
    /*
     Catalog items
     */
    NSManagedObjectContext *moc = [(MAMunkiAdmin_AppDelegate *)[NSApp delegate] managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Catalog" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entityDescription];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedStandardCompare:)]]];
    NSArray *fetchResults = [moc executeFetchRequest:fetchRequest error:nil];
    NSMutableArray *catalogItems = [NSMutableArray new];
    NSMutableArray *catalogSourceListItems = [NSMutableArray new];
    for (CatalogMO *catalog in fetchResults) {
        MAManifestsViewSourceListItem *item = [MAManifestsViewSourceListItem collectionWithTitle:catalog.title identifier:catalog.title type:ManifestSourceItemTypeFolder];
        item.filterPredicate = [NSPredicate predicateWithFormat:@"ANY catalogStrings == %@", catalog.title];
        [catalogSourceListItems addObject:item];
        [catalogItems addObject:[PXSourceListItem itemWithRepresentedObject:item icon:notepad]];
    }
    
    // Store all of the model objects in an array because each source list item only holds a weak reference to them.
    self.modelObjects = [@[allManifestsItem, recentlyModifiedItem, machineManifestsItem, groupManifestsItem, profileManifestsItem] mutableCopy];
    [self.modelObjects addObjectsFromArray:catalogSourceListItems];
    
    
    
    // Set up our Source List data model used in the Source List data source methods.
    PXSourceListItem *libraryItem = [PXSourceListItem itemWithTitle:[self uppercaseOrCapitalizedHeaderString:@"Repository"] identifier:nil];
    libraryItem.children = @[[PXSourceListItem itemWithRepresentedObject:allManifestsItem icon:inbox],
                             [PXSourceListItem itemWithRepresentedObject:recentlyModifiedItem icon:calendar]];
    
    PXSourceListItem *manifestTypesItem = [PXSourceListItem itemWithTitle:[self uppercaseOrCapitalizedHeaderString:@"Manifest Types"] identifier:nil];
    manifestTypesItem.children = @[[PXSourceListItem itemWithRepresentedObject:machineManifestsItem icon:document],
                                   [PXSourceListItem itemWithRepresentedObject:groupManifestsItem icon:documents],
                                   [PXSourceListItem itemWithRepresentedObject:profileManifestsItem icon:documentDownload],
                                   ];
    
    PXSourceListItem *catalogsItem = [PXSourceListItem itemWithTitle:[self uppercaseOrCapitalizedHeaderString:@"Catalogs"] identifier:nil];
    catalogsItem.children = [NSArray arrayWithArray:catalogItems];
    
    PXSourceListItem *directoriesItem = [self directoriesItem];
    
    [self.sourceListItems addObject:libraryItem];
    [self.sourceListItems addObject:manifestTypesItem];
    [self.sourceListItems addObject:catalogsItem];
    [self.sourceListItems addObject:directoriesItem];
}

- (NSString *)uppercaseOrCapitalizedHeaderString:(NSString *)headerTitle
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_9) {
        /* On a 10.9 - 10.9.x system */
        return [headerTitle uppercaseString];
    } else {
        /* 10.10 or later system */
        return [headerTitle capitalizedString];
    }
}

- (PXSourceListItem *)directoriesItem
{
    NSURL *mainManifestsURL = [(MAMunkiAdmin_AppDelegate *)[NSApp delegate] manifestsURL];
    PXSourceListItem *directoriesItem = [PXSourceListItem itemWithTitle:[self uppercaseOrCapitalizedHeaderString:@"Directories"] identifier:nil];
    
    if (!mainManifestsURL) {
        return directoriesItem;
    }
    
    NSMutableArray *newChildren = [NSMutableArray new];
    NSMutableArray *newRepresentedObjects = [NSMutableArray new];
    
    NSImage *folderImage = [NSImage imageNamed:@"folder"];
    
    NSString *mainManifestsTitle;
    [mainManifestsURL getResourceValue:&mainManifestsTitle forKey:NSURLNameKey error:nil];
    MAManifestsViewSourceListItem *mainManifestsItem = [MAManifestsViewSourceListItem collectionWithTitle:mainManifestsTitle identifier:mainManifestsTitle type:ManifestSourceItemTypeFolder];
    mainManifestsItem.filterPredicate = [NSPredicate predicateWithFormat:@"manifestParentDirectoryURL == %@", mainManifestsURL];
    mainManifestsItem.representedFileURL = mainManifestsURL;
    [newChildren addObject:[PXSourceListItem itemWithRepresentedObject:mainManifestsItem icon:folderImage]];
    [newRepresentedObjects addObject:mainManifestsItem];
    
    NSArray *keysToget = [NSArray arrayWithObjects:NSURLNameKey, NSURLLocalizedNameKey, NSURLIsDirectoryKey, nil];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSDirectoryEnumerator *pkgsInfoDirEnum = [fm enumeratorAtURL:mainManifestsURL includingPropertiesForKeys:keysToget options:(NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:nil];
    for (NSURL *anURL in pkgsInfoDirEnum)
    {
        NSNumber *isDir;
        [anURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
        if ([isDir boolValue]) {
            
            
            NSString *newTitle;
            [anURL getResourceValue:&newTitle forKey:NSURLNameKey error:nil];
            MAManifestsViewSourceListItem *item = [MAManifestsViewSourceListItem collectionWithTitle:newTitle identifier:newTitle type:ManifestSourceItemTypeFolder];
            item.filterPredicate = [NSPredicate predicateWithFormat:@"manifestParentDirectoryURL == %@", anURL];
            item.representedFileURL = anURL;
            
            NSURL *parentDirectory = [anURL URLByDeletingLastPathComponent];
            
            NSArray *parentURLs = [newChildren filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"representedObject.representedFileURL == %@", parentDirectory]];
            if ([parentURLs count] > 0) {
                PXSourceListItem *parent = parentURLs[0];
                [parent addChildItem:[PXSourceListItem itemWithRepresentedObject:item icon:folderImage]];
            }
            [newRepresentedObjects addObject:item];
        }
    }
    directoriesItem.children = [NSArray arrayWithArray:newChildren];
    [self.modelObjects addObjectsFromArray:newRepresentedObjects];
    return directoriesItem;
}

- (void)removeDetailViewSubviews
{
    NSArray *detailSubViews = [self.detailViewPlaceHolder subviews];
    if ([detailSubViews count] > 0)
    {
        [detailSubViews[0] removeFromSuperview];
    }
}

#pragma mark -
#pragma mark Manifest list right-click menu actions

- (IBAction)propertiesAction:(id)sender
{
    DDLogVerbose(@"%@", NSStringFromSelector(_cmd));
    NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
    ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
    if ([[self.manifestsArrayController selectedObjects] count] > 0) {
        if ([[self.manifestsArrayController selectionIndexes] containsIndex:clickedRow]) {
            for (ManifestMO *manifest in [self.manifestsArrayController selectedObjects]) {
                MAManifestEditor *editor = [self editorForManifest:manifest];
                [editor showWindow:nil];
            }
        } else {
            MAManifestEditor *editor = [self editorForManifest:clickedManifest];
            [editor showWindow:nil];
        }
    } else {
        MAManifestEditor *editor = [self editorForManifest:clickedManifest];
        [editor showWindow:nil];
    }
}

- (IBAction)showManifestInFinderAction:(id)sender
{
    DDLogVerbose(@"%@", NSStringFromSelector(_cmd));
    MAMunkiAdmin_AppDelegate *appDelegate = (MAMunkiAdmin_AppDelegate *)[NSApp delegate];
    NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
    ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
    NSURL *selectedURL;
    if ([[self.manifestsArrayController selectedObjects] count] > 0) {
        if ([[self.manifestsArrayController selectionIndexes] containsIndex:clickedRow]) {
            selectedURL = (NSURL *)[[self.manifestsArrayController selectedObjects][0] manifestURL];
        } else {
            selectedURL = [clickedManifest manifestURL];
        }
    } else {
        selectedURL = [clickedManifest manifestURL];
    }
    
    if (selectedURL != nil) {
        [[NSWorkspace sharedWorkspace] selectFile:[selectedURL relativePath] inFileViewerRootedAtPath:[appDelegate.repoURL relativePath]];
    }
}

- (void)setDetailView:(NSView *)newDetailView
{
    [self.detailViewPlaceHolder addSubview:newDetailView];
    
    [newDetailView setFrame:[self.detailViewPlaceHolder frame]];
    
    // make sure our added subview is placed and resizes correctly
    [newDetailView setFrameOrigin:NSMakePoint(0,0)];
    [newDetailView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

- (IBAction)openEditorForManifestMenuItemAction:(id)sender
{
    ManifestMO *manifest = [sender representedObject];
    [self openEditorForManifest:manifest];
}

- (void)addSelectedManifestsToCatalogAction:(id)sender
{
    CatalogMO *catalog = [sender representedObject];
    for (ManifestMO *manifest in self.manifestsArrayController.selectedObjects) {
        for (CatalogInfoMO *catalogInfo in manifest.catalogInfos) {
            if (catalogInfo.catalog == catalog) {
                catalogInfo.isEnabledForManifestValue = YES;
            }
        }
        manifest.hasUnstagedChangesValue = YES;
    }
}

- (void)removeSelectedManifestsFromCatalogAction:(id)sender
{
    CatalogMO *catalog = [sender representedObject];
    for (ManifestMO *manifest in self.manifestsArrayController.selectedObjects) {
        for (CatalogInfoMO *catalogInfo in manifest.catalogInfos) {
            if (catalogInfo.catalog == catalog) {
                catalogInfo.isEnabledForManifestValue = NO;
            }
        }
        manifest.hasUnstagedChangesValue = YES;
    }
}

- (void)enableAllCatalogsAction:(id)sender
{
    for (ManifestMO *manifest in self.manifestsArrayController.selectedObjects) {
        for (CatalogInfoMO *catalogInfo in manifest.catalogInfos) {
            catalogInfo.isEnabledForManifestValue = YES;
        }
        manifest.hasUnstagedChangesValue = YES;
    }
}

- (void)disableAllCatalogsAction:(id)sender
{
    for (ManifestMO *manifest in self.manifestsArrayController.selectedObjects) {
        for (CatalogInfoMO *catalogInfo in manifest.catalogInfos) {
            catalogInfo.isEnabledForManifestValue = NO;
        }
        manifest.hasUnstagedChangesValue = YES;
    }
}

#pragma mark -
#pragma mark NSMenu delegates

- (void)menuWillOpen:(NSMenu *)menu
{
    if (menu == self.manifestsListMenu) {
        [self manifestsListMenuWillOpen:menu];
    } else if (menu == self.catalogsSubMenu) {
        [self catalogsSubMenuWillOpen:menu];
    } else if (menu == self.referencingManifestsSubMenu) {
        [self referencingManifestsSubMenuWillOpen:menu];
    } else if (menu == self.includedManifestsSubMenu) {
        [self includedManifestsSubMenuWillOpen:menu];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    DDLogVerbose(@"Validating menu item %@", [menuItem title]);
    return YES;
}


- (void)manifestsListMenuWillOpen:(NSMenu *)menu
{
    NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
    ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
    
    if ([clickedManifest.allReferencingManifests count] == 0) {
        self.referencingManifestsSubMenuItem.hidden = YES;
    } else {
        self.referencingManifestsSubMenuItem.hidden = NO;
    }
    
    if ([clickedManifest.allIncludedManifests count] == 0) {
        self.includedManifestsSubMenuItem.hidden = YES;
    } else {
        self.includedManifestsSubMenuItem.hidden = NO;
    }
}

- (void)referencingManifestsSubMenuWillOpen:(NSMenu *)menu
{
    [menu removeAllItems];
    
    NSMutableArray *newItems = [NSMutableArray new];
    
    NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
    ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
    for (StringObjectMO *object in clickedManifest.allReferencingManifests) {
        NSString *title;
        id representedObject;
        if (object.manifestReference) {
            title = object.manifestReference.title;
            representedObject = object.manifestReference;
        } else {
            title = object.includedManifestConditionalReference.manifest.title;
            representedObject = object.includedManifestConditionalReference.manifest;
        }
        [newItems addObject:@{@"title": title, @"representedObject": representedObject}];
    }
    
    NSImage *manifestImage = [NSImage imageNamed:@"manifestIcon_32x32"];
    [manifestImage setSize:NSMakeSize(16.0, 16.0)];
    
    [newItems sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
    for (NSDictionary *object in newItems) {
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:object[@"title"]
                                                             action:nil
                                                      keyEquivalent:@""];
        ManifestMO *representedManifest = (ManifestMO *)object[@"representedObject"];
        newMenuItem.representedObject = representedManifest;
        newMenuItem.target = self;
        newMenuItem.action = @selector(openEditorForManifestMenuItemAction:);
        newMenuItem.image = manifestImage;
        [menu addItem:newMenuItem];
    }
}

- (void)includedManifestsSubMenuWillOpen:(NSMenu *)menu
{
    [menu removeAllItems];
    
    NSMutableArray *newItems = [NSMutableArray new];
    
    NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
    ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
    
    for (StringObjectMO *object in clickedManifest.allIncludedManifests) {
        NSString *title;
        id representedObject;
        if (object.originalManifest) {
            title = object.originalManifest.title;
            representedObject = object.originalManifest;
            [newItems addObject:@{@"title": title, @"representedObject": representedObject}];
        } else {
            DDLogError(@"Error. Included manifest object %@ doesn't have reference to its original manifest.", object.description);
        }
    }
    
    NSImage *manifestImage = [NSImage imageNamed:@"manifestIcon_32x32"];
    [manifestImage setSize:NSMakeSize(16.0, 16.0)];
    
    [newItems sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]]];
    for (NSDictionary *object in newItems) {
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:object[@"title"]
                                                             action:nil
                                                      keyEquivalent:@""];
        ManifestMO *representedManifest = (ManifestMO *)object[@"representedObject"];
        newMenuItem.representedObject = representedManifest;
        newMenuItem.target = self;
        newMenuItem.action = @selector(openEditorForManifestMenuItemAction:);
        newMenuItem.image = manifestImage;
        [menu addItem:newMenuItem];
    }
}

- (void)catalogsSubMenuWillOpen:(NSMenu *)menu
{
    [menu removeAllItems];
    
    NSMenuItem *enableAllCatalogsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Enable All Catalogs"
                                                                       action:@selector(enableAllCatalogsAction:)
                                                                keyEquivalent:@""];
    [enableAllCatalogsMenuItem setEnabled:YES];
    enableAllCatalogsMenuItem.target = self;
    [menu addItem:enableAllCatalogsMenuItem];
    
    
    NSMenuItem *disableAllCatalogsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Disable All Catalogs"
                                                                        action:@selector(disableAllCatalogsAction:)
                                                                 keyEquivalent:@""];
    
    [disableAllCatalogsMenuItem setEnabled:YES];
    disableAllCatalogsMenuItem.target = self;
    [menu addItem:disableAllCatalogsMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    
    /*
     Create a menu item for each catalog object
     */
    NSManagedObjectContext *moc = [(MAMunkiAdmin_AppDelegate *)[NSApp delegate] managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Catalog" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entityDescription];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedStandardCompare:)]]];
    NSArray *fetchResults = [moc executeFetchRequest:fetchRequest error:nil];
    for (CatalogMO *catalog in fetchResults) {
        
        NSMenuItem *catalogItem = [[NSMenuItem alloc] initWithTitle:catalog.title
                                                             action:nil
                                                      keyEquivalent:@""];
        catalogItem.representedObject = catalog;
        catalogItem.target = self;
        [menu addItem:catalogItem];
        
        
        /*
         Set the state of the menu item
         */
        int numEnabled = 0;
        int numDisabled = 0;
        NSMutableArray *enabledPackageNames = [NSMutableArray new];
        NSMutableArray *disabledPackageNames = [NSMutableArray new];
        
        for (ManifestMO *manifest in self.manifestsArrayController.selectedObjects) {
            if ([[manifest catalogStrings] containsObject:catalog.title]) {
                [enabledPackageNames addObject:manifest.title];
                numEnabled++;
            } else {
                [disabledPackageNames addObject:manifest.title];
                numDisabled++;
            }
        }
        
        NSUInteger clickedRow = (NSUInteger)[self.manifestsListTableView clickedRow];
        ManifestMO *clickedManifest = [[self.manifestsArrayController arrangedObjects] objectAtIndex:clickedRow];
        if ([[clickedManifest catalogStrings] containsObject:catalog.title]) {
            [enabledPackageNames addObject:clickedManifest.title];
            numEnabled++;
        } else {
            [disabledPackageNames addObject:clickedManifest.title];
            numDisabled++;
        }
        
        if (numDisabled == 0) {
            /*
             All of the selected manifests are in this catalog.
             Selecting this menu item should remove manifests from catalog.
             */
            catalogItem.action = @selector(removeSelectedManifestsFromCatalogAction:);
            catalogItem.state = NSOnState;
            
        } else if (numEnabled == 0) {
            /*
             None of the selected manifests are in this catalog.
             Selecting this menu item should add manifests to this catalog.
             */
            catalogItem.action = @selector(addSelectedManifestsToCatalogAction:);
            catalogItem.state = NSOffState;
            
        } else {
            /*
             Some of the selected manifests are in this catalog.
             Selecting this menu item should add the missing manifests to this catalog.
             
             Additionally create a tooltip to show which manifests are enabled/disable.
             */
            NSString *toolTip;
            if (numEnabled > numDisabled) {
                toolTip = [NSString stringWithFormat:@"Manifests not using catalog \"%@\":\n- %@",
                           catalog.title,
                           [disabledPackageNames componentsJoinedByString:@"\n- "]];
            } else {
                toolTip = [NSString stringWithFormat:@"Manifests using catalog \"%@\":\n- %@",
                           catalog.title,
                           [enabledPackageNames componentsJoinedByString:@"\n- "]];
            }
            catalogItem.toolTip = toolTip;
            
            catalogItem.action = @selector(addSelectedManifestsToCatalogAction:);
            catalogItem.state = NSMixedState;
        }
        
    }
}


# pragma mark -
# pragma mark PXSourceList Data Source methods

- (NSUInteger)sourceList:(PXSourceList*)sourceList numberOfChildrenOfItem:(id)item
{
    if (!item)
        return self.sourceListItems.count;
    
    return [[item children] count];
}

- (id)sourceList:(PXSourceList*)aSourceList child:(NSUInteger)index ofItem:(id)item
{
    if (!item)
        return self.sourceListItems[index];
    
    return [[item children] objectAtIndex:index];
}

- (BOOL)sourceList:(PXSourceList*)aSourceList isItemExpandable:(id)item
{
    return [item hasChildren];
}

# pragma mark -
# pragma mark PXSourceList Delegate


- (void)sourceListSelectionDidChange:(NSNotification *)notification
{
    if ([self.sourceList selectedRow] >= 0) {
        DDLogVerbose(@"Starting to set predicate...");
        id selectedItem = [self.sourceList itemAtRow:[self.sourceList selectedRow]];
        NSPredicate *productFilter = [(MAManifestsViewSourceListItem *)[selectedItem representedObject] filterPredicate];
        self.selectedSourceListFilterPredicate = productFilter;
        
        NSArray *productSortDescriptors = [(MAManifestsViewSourceListItem *)[selectedItem representedObject] sortDescriptors];
        
        if (productSortDescriptors != nil) {
            [self.manifestsArrayController setSortDescriptors:productSortDescriptors];
        } else {
            [self.manifestsArrayController setSortDescriptors:self.defaultSortDescriptors];
        }
        DDLogVerbose(@"Finished setting predicate...");
    }
}

- (BOOL)sourceList:(PXSourceList *)aSourceList isGroupAlwaysExpanded:(id)group
{
    return NO;
}

- (NSView *)sourceList:(PXSourceList *)aSourceList viewForItem:(id)item
{
    PXSourceListTableCellView *cellView = nil;
    if ([aSourceList levelForItem:item] == 0)
        cellView = [aSourceList makeViewWithIdentifier:@"HeaderCell" owner:nil];
    else
        cellView = [aSourceList makeViewWithIdentifier:@"MainCell" owner:nil];
    
    PXSourceListItem *sourceListItem = item;
    MAManifestsViewSourceListItem *collection = sourceListItem.representedObject;
    
    // Only allow us to edit the user created items.
    BOOL isTitleEditable = [collection isKindOfClass:[MAManifestsViewSourceListItem class]] && collection.type == ManifestSourceItemTypeUserCreated;
    cellView.textField.editable = isTitleEditable;
    cellView.textField.selectable = isTitleEditable;
    
    cellView.textField.stringValue = sourceListItem.title ? sourceListItem.title : [sourceListItem.representedObject title];
    cellView.imageView.image = [item icon];
    cellView.badgeView.hidden = YES;
    //cellView.badgeView.badgeValue = ...;
    
    return cellView;
}

-(BOOL)sourceList:(PXSourceList *)aSourceList shouldShowOutlineCellForItem:(id)item
{
    /*
     Don't show disclosure triangle for subitems
     */
    if ([aSourceList levelForItem:item] == 0) {
        return YES;
    } else {
        return NO;
    }
}


# pragma mark -
# pragma mark NSSplitView delegates

- (void)toggleManifestsFindView
{
    BOOL findViewCollapsed = [self.manifestsListSplitView isSubviewCollapsed:[self.manifestsListSplitView subviews][0]];
    if (findViewCollapsed) {
        self.manifestsListPredicateEditor.objectValue = self.previousPredicateEditorPredicate;
        self.searchFieldPredicate = self.previousPredicateEditorPredicate;
        [self searchUpdated:nil];
        [self uncollapseFindView];
        
        [self.view.window makeFirstResponder:self.manifestsListPredicateEditor];
        [self.view.window selectKeyViewFollowingView:self.manifestsListPredicateEditor];
        [self.view.window recalculateKeyViewLoop];
        
    } else {
        self.previousPredicateEditorPredicate = self.manifestsListPredicateEditor.objectValue;
        self.searchFieldPredicate = [NSPredicate predicateWithValue:YES];
        [self collapseFindView];
        [self.view.window makeFirstResponder:self.manifestsListTableView];
        [self.manifestsListTableView setNextKeyView:self.sourceList];
        [self.sourceList setNextKeyView:self.manifestsListTableView];
         
    }
}

- (void)collapseFindView
{
    NSView *predicateEditorSubView = [self.manifestsListSplitView subviews][0];
    NSView *manifestsListSubView  = [self.manifestsListSplitView subviews][1];
    NSRect overallFrame = [self.detailViewPlaceHolder frame];
    [predicateEditorSubView setHidden:YES];
    
    [manifestsListSubView setFrameSize:NSMakeSize(overallFrame.size.width,overallFrame.size.height)];
    
    [self.manifestsListSplitView display];
}

- (void)uncollapseFindView
{
    NSView *predicateEditorSubView = [self.manifestsListSplitView subviews][0];
    NSView *manifestsListSubView  = [self.manifestsListSplitView subviews][1];
    NSRect overallFrame = [self.detailViewPlaceHolder frame];
    
    [predicateEditorSubView setHidden:NO];
    
    NSRect manifestsListFrame = [manifestsListSubView frame];
    NSRect predicateEditorFrame = [predicateEditorSubView frame];
    
    CGFloat predEditorRowHeight = [self.manifestsListPredicateEditor rowHeight];
    NSInteger numRowsInPredEditor = [self.manifestsListPredicateEditor numberOfRows];
    int padding = 32;
    CGFloat desiredHeight = numRowsInPredEditor * predEditorRowHeight + padding;
    CGFloat dividerThickness = [self.manifestsListSplitView dividerThickness];
    predicateEditorFrame.size.height = desiredHeight;
    manifestsListFrame.size.height = (overallFrame.size.height - predicateEditorFrame.size.height - dividerThickness);
    predicateEditorFrame.origin.y = manifestsListFrame.size.height + dividerThickness;
    
    [manifestsListSubView setFrameSize:manifestsListFrame.size];
    [predicateEditorSubView setFrame:predicateEditorFrame];
    
    [self.manifestsListSplitView display];
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    if (splitView == self.mainSplitView) {
        return NO;
    } else if ((splitView == self.manifestsListSplitView) && (subview == [self.manifestsListSplitView subviews][0])) {
        return NO;
    } else {
        return NO;
    }
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    if (splitView == self.manifestsListSplitView) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
    if (splitView == self.mainSplitView) {
        return NO;
    } else if (splitView == self.manifestsListSplitView && subview == [self.manifestsListSplitView subviews][0]) {
        return YES;
    } else {
        return NO;
    }
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    if (splitView == self.mainSplitView) {
        /*
         User is dragging the left side divider
         */
        if (dividerIndex == 0) {
            return kMinSplitViewWidth;
        }
        /*
         User is dragging the right side divider
         */
        else if (dividerIndex == 1) {
            return proposedMin;
        }
    } else if (splitView == self.manifestsListSplitView) {
        if (dividerIndex == 0) {
            return [[self.manifestsListSplitView subviews][0] frame].size.height;
        }
    }
    return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    if (splitView == self.mainSplitView) {
        /*
         User is dragging the left side divider
         */
        if (dividerIndex == 0) {
            return kMaxSplitViewWidth;
        }
        /*
         User is dragging the right side divider
         */
        else if (dividerIndex == 1) {
            return [self.mainSplitView frame].size.width - kMinSplitViewWidth;
        }
    } else if (splitView == self.manifestsListSplitView) {
        if (dividerIndex == 0) {
            return [[self.manifestsListSplitView subviews][0] frame].size.height;
        }
    }
    return proposedMax;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    if (sender == self.mainSplitView) {
        /*
         Main split view
         Resize only the right side of the splitview
         */
        NSView *left = [sender subviews][0];
        NSView *right = [sender subviews][1];
        CGFloat dividerThickness = [sender dividerThickness];
        NSRect newFrame = [sender frame];
        NSRect leftFrame = [left frame];
        NSRect rightFrame = [right frame];
        
        rightFrame.size.height = newFrame.size.height;
        rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
        rightFrame.origin = NSMakePoint(leftFrame.size.width + dividerThickness, 0);
        
        leftFrame.size.height = newFrame.size.height;
        leftFrame.origin.x = 0;
        
        [left setFrame:leftFrame];
        [right setFrame:rightFrame];
    } else if (sender == self.manifestsListSplitView) {
        /*
         Manifests list split view should be resized automatically
         if the predicate view (top) is hidden. Otherwise only resize
         the bottom view.
         */
        NSView *topView = [sender subviews][0];
        NSView *bottomView = [sender subviews][1];
        
        CGFloat dividerThickness = [sender dividerThickness];
        NSRect newFrame = [sender frame];
        NSRect topFrame = [topView frame];
        NSRect bottomFrame = [bottomView frame];
         
        if ([sender isSubviewCollapsed:topView]) {
            [sender adjustSubviews];
        } else {
            topFrame.size.width = newFrame.size.width;
            topFrame.origin = NSMakePoint(0, 0);
            
            bottomFrame.size.height = newFrame.size.height - topFrame.size.height - dividerThickness;
            bottomFrame.size.width = newFrame.size.width;
            bottomFrame.origin.y = topFrame.size.height + dividerThickness;
            
            [topView setFrame:topFrame];
            [bottomView setFrame:bottomFrame];
        }
    }
}


@end
