#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSFetchRequest.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObjectContext, NSManagedObjectID;
@protocol NSFetchedResultsControllerDelegate, NSFetchedResultsSectionInfo;

/// The snapshot the delegate gets (controller(_:didChangeContentWith:)) is UIKit's NSDiffableDataSourceSnapshotReference
/// (UIDiffableDataSourceReference.h; Swift: bridges to NSDiffableDataSourceSnapshot<String, NSManagedObjectID> with `as`).
@class NSDiffableDataSourceSnapshotReference;

@interface NSFetchedResultsController<ResultType : id<NSFetchRequestResult>> : NSObject
- (instancetype)initWithFetchRequest:(NSFetchRequest<ResultType> *)fetchRequest managedObjectContext:(NSManagedObjectContext *)context sectionNameKeyPath:(nullable NSString *)sectionNameKeyPath cacheName:(nullable NSString *)name;
- (BOOL)performFetch:(NSError **)error;
@property (nonatomic, readonly) NSFetchRequest<ResultType> *fetchRequest;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nullable, nonatomic, readonly) NSString *sectionNameKeyPath;
@property (nullable, nonatomic, readonly) NSString *cacheName;
@property (nullable, nonatomic, weak) id<NSFetchedResultsControllerDelegate> delegate;
+ (void)deleteCacheWithName:(nullable NSString *)name;
@property (nullable, nonatomic, readonly) NSArray<ResultType> *fetchedObjects;
- (ResultType)objectAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForObject:(ResultType)object;
- (nullable NSString *)sectionIndexTitleForSectionName:(NSString *)sectionName;
@property (nonatomic, readonly) NSArray<NSString *> *sectionIndexTitles;
@property (nullable, nonatomic, readonly) NSArray<id<NSFetchedResultsSectionInfo>> *sections;
- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)sectionIndex;
@end

@protocol NSFetchedResultsSectionInfo
@property (nonatomic, readonly) NSString *name;
@property (nullable, nonatomic, readonly) NSString *indexTitle;
@property (nonatomic, readonly) NSUInteger numberOfObjects;
@property (nullable, nonatomic, readonly) NSArray *objects;
@end

typedef NS_ENUM(NSUInteger, NSFetchedResultsChangeType) {
    NSFetchedResultsChangeInsert NS_SWIFT_NAME(insert) = 1,
    NSFetchedResultsChangeDelete NS_SWIFT_NAME(delete) = 2,
    NSFetchedResultsChangeMove NS_SWIFT_NAME(move) = 3,
    NSFetchedResultsChangeUpdate NS_SWIFT_NAME(update) = 4
};

/// isim: when the delegate implements controller:didChangeContentWithSnapshot:, only that is called (like iOS).
@protocol NSFetchedResultsControllerDelegate <NSObject>
@optional
- (void)controller:(NSFetchedResultsController *)controller didChangeContentWithSnapshot:(NSDiffableDataSourceSnapshotReference *)snapshot NS_SWIFT_NAME(controller(_:didChangeContentWith:));
- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(nullable NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(nullable NSIndexPath *)newIndexPath NS_SWIFT_NAME(controller(_:didChange:at:for:newIndexPath:));
- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type NS_SWIFT_NAME(controller(_:didChange:atSectionIndex:for:));
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller;
- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller;
- (nullable NSString *)controller:(NSFetchedResultsController *)controller sectionIndexTitleForSectionName:(NSString *)sectionName;
@end

NS_ASSUME_NONNULL_END
