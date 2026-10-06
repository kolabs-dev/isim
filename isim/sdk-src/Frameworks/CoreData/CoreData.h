#pragma once
/* isim SDK (self-authored): Core Data — managed object models, contexts, SQLite and in-memory stores,
 * fetch requests (predicates run as SQL where possible), batch requests, NSFetchedResultsController,
 * NSPersistentContainer. API-compatible names; not Apple's headers.
 * isim: models compiled by `isim build` from .xcdatamodeld are JSON files in isim's own format (see
 * docs/COREDATA.md), not Apple's binary .mom; SQLite stores use isim's own schema. */
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSManagedObjectModel.h>
#import <CoreData/NSManagedObject.h>
#import <CoreData/NSFetchRequest.h>
#import <CoreData/NSManagedObjectContext.h>
#import <CoreData/NSPersistentStoreCoordinator.h>
#import <CoreData/NSFetchedResultsController.h>
