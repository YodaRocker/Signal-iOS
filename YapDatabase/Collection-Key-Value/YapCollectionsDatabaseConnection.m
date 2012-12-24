#import "YapCollectionsDatabaseConnection.h"
#import "YapCollectionsDatabasePrivate.h"

#import "YapAbstractDatabasePrivate.h"

#import "YapDatabaseString.h"
#import "YapDatabaseLogging.h"
#import "YapCache.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Define log level for this file.
 * See YapDatabaseLogging.h for more information.
**/
#if DEBUG
  static const int ydbFileLogLevel = YDB_LOG_LEVEL_INFO;
#else
  static const int ydbFileLogLevel = YDB_LOG_LEVEL_WARN;
#endif


@implementation YapCollectionsDatabaseConnection {

/* As defined in YapCollectionsDatabasePrivate.h :

@private
	sqlite3_stmt *getCollectionCountStatement;
	sqlite3_stmt *getKeyCountForCollectionStatement;
	sqlite3_stmt *getKeyCountForAllStatement;
	sqlite3_stmt *getCountForKeyStatement;
	sqlite3_stmt *getDataForKeyStatement;
	sqlite3_stmt *getMetadataForKeyStatement;
	sqlite3_stmt *getAllForKeyStatement;
	sqlite3_stmt *setAllForKeyStatement;
	sqlite3_stmt *setMetaForKeyStatement;
	sqlite3_stmt *removeForKeyStatement;
	sqlite3_stmt *removeCollectionStatement;
	sqlite3_stmt *removeAllStatement;
	sqlite3_stmt *enumerateCollectionsStatement;
	sqlite3_stmt *enumerateKeysInCollectionStatement;
	sqlite3_stmt *enumerateMetadataInCollectionStatement;
	sqlite3_stmt *enumerateMetadataInAllCollectionsStatement;
	sqlite3_stmt *enumerateAllInCollectionStatement;
	sqlite3_stmt *enumerateAllInAllCollectionsStatement;

*/
/* Defined in YapAbstractDatabasePrivate.h:

@protected
	dispatch_queue_t connectionQueue;
	void *IsOnConnectionQueueKey;
	
	YapAbstractDatabase *database;
	
	NSTimeInterval cacheLastWriteTimestamp;
	
@public
	sqlite3 *db;
	
	id objectCache;   // Either NSMutableDictionary (if unlimited) or YapCache (if limited)
	id metadataCache; // Either NSMutableDictionary (if unlimited) or YapCache (if limited)
	
	NSUInteger objectCacheLimit;          // Read-only by transaction. Use as consideration of whether to add to cache.
	NSUInteger metadataCacheLimit;        // Read-only by transaction. Use as consideration of whether to add to cache.
	
	BOOL hasMarkedSqlLevelSharedReadLock; // Read-only by transaction. Use as consideration of whether to invoke method.
	
	NSMutableSet *changedKeys;
	BOOL allKeysRemoved;
*/
}

- (void)dealloc
{
	sqlite_finalize_null(&getCollectionCountStatement);
	sqlite_finalize_null(&getKeyCountForCollectionStatement);
	sqlite_finalize_null(&getKeyCountForAllStatement);
	sqlite_finalize_null(&getCountForKeyStatement);
	sqlite_finalize_null(&getDataForKeyStatement);
	sqlite_finalize_null(&setMetaForKeyStatement);
	sqlite_finalize_null(&setAllForKeyStatement);
	sqlite_finalize_null(&removeForKeyStatement);
	sqlite_finalize_null(&removeCollectionStatement);
	sqlite_finalize_null(&removeAllStatement);
	sqlite_finalize_null(&enumerateCollectionsStatement);
	sqlite_finalize_null(&enumerateKeysInCollectionStatement);
	sqlite_finalize_null(&enumerateMetadataInCollectionStatement);
	sqlite_finalize_null(&enumerateMetadataInAllCollectionsStatement);
	sqlite_finalize_null(&enumerateAllInCollectionStatement);
	sqlite_finalize_null(&enumerateAllInAllCollectionsStatement);
}

/**
 * Optional override hook from YapAbstractDatabaseConnection.
**/
- (void)_trimMemory:(int)aggressiveLevel
{
	[super _trimMemory:aggressiveLevel];
	
	if (aggressiveLevel >= 1) // Moderate
	{
		sqlite_finalize_null(&getCollectionCountStatement);
		sqlite_finalize_null(&getKeyCountForAllStatement);
		sqlite_finalize_null(&getCountForKeyStatement);
		sqlite_finalize_null(&setMetaForKeyStatement);
		sqlite_finalize_null(&removeForKeyStatement);
		sqlite_finalize_null(&removeCollectionStatement);
		sqlite_finalize_null(&removeAllStatement);
		sqlite_finalize_null(&enumerateCollectionsStatement);
		sqlite_finalize_null(&enumerateKeysInCollectionStatement);
		sqlite_finalize_null(&enumerateMetadataInCollectionStatement);
		sqlite_finalize_null(&enumerateMetadataInAllCollectionsStatement);
		sqlite_finalize_null(&enumerateAllInCollectionStatement);
		sqlite_finalize_null(&enumerateAllInAllCollectionsStatement);
	}
	
	if (aggressiveLevel >= 2) // Full
	{
		sqlite_finalize_null(&getDataForKeyStatement);
		sqlite_finalize_null(&setAllForKeyStatement);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (YapCollectionsDatabase *)database
{
	return (YapCollectionsDatabase *)database;
}

- (Class)cacheKeyClass
{
	return [YapCacheCollectionKey class];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Statements
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (sqlite3_stmt *)getCollectionCountStatement
{
	if (getCollectionCountStatement == NULL)
	{
		char *stmt = "SELECT COUNT(DISTINCT collection) AS NumberOfRows FROM \"database\";";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getCollectionCountStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getCollectionCountStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getCollectionCountStatement;
}

- (sqlite3_stmt *)getKeyCountForCollectionStatement
{
	if (getKeyCountForCollectionStatement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"database\" WHERE \"collection\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getKeyCountForCollectionStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getKeyCountForCollectionStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getKeyCountForCollectionStatement;
}

- (sqlite3_stmt *)getKeyCountForAllStatement
{
	if (getKeyCountForAllStatement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"database\";";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getKeyCountForAllStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getKeyCountForAllStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getKeyCountForAllStatement;
}

- (sqlite3_stmt *)getCountForKeyStatement
{
	if (getCountForKeyStatement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"database\" WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getCountForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getCountForKeyStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getCountForKeyStatement;
}

- (sqlite3_stmt *)getDataForKeyStatement
{
	if (getDataForKeyStatement == NULL)
	{
		char *stmt = "SELECT \"data\" FROM \"database\" WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getDataForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getDataForKeyStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getDataForKeyStatement;
}

- (sqlite3_stmt *)getMetadataForKeyStatement
{
	if (getMetadataForKeyStatement == NULL)
	{
		char *stmt = "SELECT \"metadata\" FROM \"database\" WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getMetadataForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getMetadataForKeyStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getMetadataForKeyStatement;
}

- (sqlite3_stmt *)getAllForKeyStatement
{
	if (getAllForKeyStatement == NULL)
	{
		char *stmt = "SELECT \"data\", \"metadata\" FROM \"database\" WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &getAllForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'getAllForKeyStatement': %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return getAllForKeyStatement;
}

- (sqlite3_stmt *)setMetaForKeyStatement
{
	if (setMetaForKeyStatement == NULL)
	{
		char *stmt = "UPDATE \"database\" SET \"metadata\" = ? WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &setMetaForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'setMetaForKeyStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return setMetaForKeyStatement;
}

- (sqlite3_stmt *)setAllForKeyStatement
{
	if (setAllForKeyStatement == NULL)
	{
		char *stmt = "INSERT OR REPLACE INTO \"database\""
		              " (\"collection\", \"key\", \"data\", \"metadata\") VALUES (?, ?, ?, ?);";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &setAllForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'setAllForKeyStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return setAllForKeyStatement;
}

- (sqlite3_stmt *)removeForKeyStatement
{
	if (removeForKeyStatement == NULL)
	{
		char *stmt = "DELETE FROM \"database\" WHERE \"collection\" = ? AND \"key\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &removeForKeyStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'removeForKeyStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return removeForKeyStatement;
}

- (sqlite3_stmt *)removeCollectionStatement
{
	if (removeCollectionStatement == NULL)
	{
		char *stmt = "DELETE FROM \"database\" WHERE \"collection\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &removeCollectionStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'removeAllStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return removeCollectionStatement;
}

- (sqlite3_stmt *)removeAllStatement
{
	if (removeAllStatement == NULL)
	{
		char *stmt = "DELETE FROM \"database\";";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &removeAllStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'removeAllStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return removeAllStatement;
}

- (sqlite3_stmt *)enumerateCollectionsStatement
{
	if (enumerateCollectionsStatement == NULL)
	{
		char *stmt = "SELECT DISTINCT \"collection\" FROM \"database\";";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateCollectionsStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateCollectionsStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateCollectionsStatement;
}

- (sqlite3_stmt *)enumerateKeysInCollectionStatement
{
	if (enumerateKeysInCollectionStatement == NULL)
	{
		char *stmt = "SELECT \"key\" FROM \"database\" WHERE collection = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateKeysInCollectionStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateKeysInCollectionStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateKeysInCollectionStatement;
}

- (sqlite3_stmt *)enumerateMetadataInCollectionStatement
{
	if (enumerateMetadataInCollectionStatement == NULL)
	{
		char *stmt = "SELECT \"key\", \"metadata\" FROM \"database\" WHERE collection = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateMetadataInCollectionStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateMetadataInCollectionStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateMetadataInCollectionStatement;
}

- (sqlite3_stmt *)enumerateMetadataInAllCollectionsStatement
{
	if (enumerateMetadataInAllCollectionsStatement == NULL)
	{
		char *stmt = "SELECT \"collection\", \"key\", \"metadata\" FROM \"database\" ORDER BY \"collection\" ASC;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateMetadataInAllCollectionsStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateMetadataInAllCollectionsStatement'! %d %s",
			            status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateMetadataInAllCollectionsStatement;
}

- (sqlite3_stmt *)enumerateAllInCollectionStatement
{
	if (enumerateAllInCollectionStatement == NULL)
	{
		char *stmt = "SELECT \"key\", \"data\", \"metadata\" FROM \"database\" WHERE \"collection\" = ?;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateAllInCollectionStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateAllInCollectionStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateAllInCollectionStatement;
}

- (sqlite3_stmt *)enumerateAllInAllCollectionsStatement
{
	if (enumerateAllInAllCollectionsStatement == NULL)
	{
		char *stmt =
		    "SELECT \"collection\", \"key\", \"data\", \"metadata\""
		    " FROM \"database\""
		    " ORDER BY \"collection\" ASC;";
		
		int status = sqlite3_prepare_v2(db, stmt, strlen(stmt)+1, &enumerateAllInAllCollectionsStatement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'enumerateAllInAllCollectionsStatement'! %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	return enumerateAllInAllCollectionsStatement;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Access
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Read-only access to the database.
 *
 * The given block can run concurrently with sibling connections,
 * regardless of whether the sibling connections are executing read-only or read-write transactions.
**/
- (void)readWithBlock:(void (^)(YapCollectionsDatabaseReadTransaction *))block
{
	[super _readWithBlock:block];
}

/**
 * Read-write access to the database.
 * 
 * Only a single read-write block can execute among all sibling connections.
 * Thus this method may block if another sibling connection is currently executing a read-write block.
**/
- (void)readWriteWithBlock:(void (^)(YapCollectionsDatabaseReadWriteTransaction *transaction))block
{
	[super _readWriteWithBlock:block];
}

/**
 * Read-only access to the database.
 *
 * The given block can run concurrently with sibling connections,
 * regardless of whether the sibling connections are executing read-only or read-write transactions.
 *
 * This method is asynchronous.
**/
- (void)asyncReadWithBlock:(void (^)(YapCollectionsDatabaseReadTransaction *transaction))block
{
	[super _asyncReadWithBlock:block completionBlock:NULL completionQueue:NULL];
}

/**
 * Read-write access to the database.
 *
 * The given block can run concurrently with sibling connections,
 * regardless of whether the sibling connections are executing read-only or read-write transactions.
 *
 * This method is asynchronous.
 * 
 * An optional completion block may be used.
 * The completionBlock will be invoked on the main thread (dispatch_get_main_queue()).
**/
- (void)asyncReadWithBlock:(void (^)(YapCollectionsDatabaseReadTransaction *transaction))block
           completionBlock:(dispatch_block_t)completionBlock
{
	[super _asyncReadWithBlock:block completionBlock:completionBlock completionQueue:NULL];
}

/**
 * Read-write access to the database.
 *
 * The given block can run concurrently with sibling connections,
 * regardless of whether the sibling connections are executing read-only or read-write transactions.
 *
 * This method is asynchronous.
 * 
 * An optional completion block may be used.
 * Additionally the dispatch_queue to invoke the completion block may also be specified.
 * If NULL, dispatch_get_main_queue() is automatically used.
**/
- (void)asyncReadWithBlock:(void (^)(YapCollectionsDatabaseReadTransaction *transaction))block
           completionBlock:(dispatch_block_t)completionBlock
           completionQueue:(dispatch_queue_t)completionQueue
{
	[super _asyncReadWithBlock:block completionBlock:completionBlock completionQueue:completionQueue];
}

/**
 * Read-write access to the database.
 * 
 * Only a single read-write block can execute among all sibling connections.
 * Thus this method may block if another sibling connection is currently executing a read-write block.
 * 
 * This method is asynchronous.
**/
- (void)asyncReadWriteWithBlock:(void (^)(YapCollectionsDatabaseReadWriteTransaction *transaction))block
{
	[super _asyncReadWriteWithBlock:block completionBlock:NULL completionQueue:NULL];
}

/**
 * Read-write access to the database.
 *
 * Only a single read-write block can execute among all sibling connections.
 * Thus the execution of the block may be delayted if another sibling connection
 * is currently executing a read-write block.
 *
 * This method is asynchronous.
 * 
 * An optional completion block may be used.
 * The completionBlock will be invoked on the main thread (dispatch_get_main_queue()).
**/
- (void)asyncReadWriteWithBlock:(void (^)(YapCollectionsDatabaseReadWriteTransaction *transaction))block
                completionBlock:(dispatch_block_t)completionBlock
{
	[super _asyncReadWriteWithBlock:block completionBlock:completionBlock completionQueue:NULL];
}

/**
 * Read-write access to the database.
 *
 * Only a single read-write block can execute among all sibling connections.
 * Thus the execution of the block may be delayted if another sibling connection
 * is currently executing a read-write block.
 *
 * This method is asynchronous.
 * 
 * An optional completion block may be used.
 * Additionally the dispatch_queue to invoke the completion block may also be specified.
 * If NULL, dispatch_get_main_queue() is automatically used.
**/
- (void)asyncReadWriteWithBlock:(void (^)(YapCollectionsDatabaseReadWriteTransaction *transaction))block
                completionBlock:(dispatch_block_t)completionBlock
                completionQueue:(dispatch_queue_t)completionQueue
{
	[super _asyncReadWriteWithBlock:block completionBlock:completionBlock completionQueue:completionQueue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark States
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Required method.
 * Returns the proper type of transaction for this connection class.
**/
- (YapAbstractDatabaseTransaction *)newReadTransaction
{
	return [[YapCollectionsDatabaseReadTransaction alloc] initWithConnection:self];
}

/**
 * Required method.
 * Returns the proper type of transaction for this connection class.
**/
- (YapAbstractDatabaseTransaction *)newReadWriteTransaction
{
	return [[YapCollectionsDatabaseReadWriteTransaction alloc] initWithConnection:self];
}

/**
 * We override this method to ensure 'resetCollections' is prepared for use.
**/
- (void)preReadWriteTransaction:(YapAbstractDatabaseTransaction *)transaction
{
	[super preReadWriteTransaction:transaction];
	
	if (resetCollections == nil)
		resetCollections = [[NSMutableSet alloc] init];
}

/**
 * We override this method to purge 'resetCollections'.
**/
- (void)postReadWriteTransaction:(YapAbstractDatabaseTransaction *)transaction
{
	[super postReadWriteTransaction:transaction];
	
	[resetCollections removeAllObjects];
}

/**
 * This method is invoked from within the postReadWriteTransaction operations.
 * This method is invoked before anything has been committed.
 *
 * If changes have been made, it should return a changeset dictionary.
 * If no changes have been made, it should return nil.
 *
 * The changeset will ultimatesly be passed to sibling connections via noteChanges:.
**/
- (NSMutableDictionary *)changeset
{
	NSMutableDictionary *changeset = [super changeset];
	
	if ([resetCollections count] > 0)
	{
		if (changeset == nil)
			changeset = [NSMutableDictionary dictionaryWithCapacity:2]; // For "resetCollections" & "lastWriteTimestamp"
		
		[changeset setObject:[resetCollections allObjects] forKey:@"resetCollections"];
	}
	
	return changeset;
}

/**
 * Optional override hook.
 * Don't forget to invoke [super noteChanges:changeset].
 *
 * This method is invoked when a sibling connection (a separate connection for the same database)
 * finishes making a change to the database. We take this opportunity to flush from our cache anything that changed.
 * This allows us to keep our cache mostly full, and just discard changed items.
 * 
 * Note: This is an optimization that may occasionally be spoiled due to the multi-threaded nature of connections.
 * For example, if a separate connection in another thread makes a change, then by the time we get this notification,
 * our connection may have already begun a transaction. The atomic snapshot architecture takes over at that point,
 * and will detect the race condition, and fully flush the cache. This method is an optimization that
 * allows us to avoid the full flush a majority of the time.
**/
- (void)noteChanges:(NSDictionary *)changeset
{
	[super noteChanges:changeset];
	
	NSArray *_resetCollections = [changeset objectForKey:@"resetCollections"];
	if (_resetCollections)
	{
		for (NSString *collection in _resetCollections)
		{
			BOOL(^filter)(id, id, BOOL*) = ^BOOL (id key, id obj, BOOL *stop) {
				
				__unsafe_unretained YapCacheCollectionKey *cacheKey = (YapCacheCollectionKey *)key;
				return [cacheKey.collection isEqualToString:collection];
			};
			
			NSSet *objectCacheKeys = [objectCache keysOfEntriesPassingTest:filter];
			NSSet *metadataCacheKeys = [metadataCache keysOfEntriesPassingTest:filter];
			
			[objectCache removeObjectsForKeys:[objectCacheKeys allObjects]];
			[metadataCache removeObjectsForKeys:[metadataCacheKeys allObjects]];
		}
	}
}

@end
