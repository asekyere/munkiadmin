// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to PackageSourceListItemMO.m instead.

#import "_PackageSourceListItemMO.h"

const struct PackageSourceListItemMOAttributes PackageSourceListItemMOAttributes = {
	.filterPredicate = @"filterPredicate",
	.icon = @"icon",
	.isGroupItem = @"isGroupItem",
	.itemType = @"itemType",
	.originalIndex = @"originalIndex",
	.sortDescriptors = @"sortDescriptors",
	.title = @"title",
};

const struct PackageSourceListItemMORelationships PackageSourceListItemMORelationships = {
	.children = @"children",
	.parent = @"parent",
};

@implementation PackageSourceListItemMOID
@end

@implementation _PackageSourceListItemMO

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"PackageSourceListItem" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"PackageSourceListItem";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"PackageSourceListItem" inManagedObjectContext:moc_];
}

- (PackageSourceListItemMOID*)objectID {
	return (PackageSourceListItemMOID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];

	if ([key isEqualToString:@"isGroupItemValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isGroupItem"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"originalIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"originalIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}

@dynamic filterPredicate;

@dynamic icon;

@dynamic isGroupItem;

- (BOOL)isGroupItemValue {
	NSNumber *result = [self isGroupItem];
	return [result boolValue];
}

- (void)setIsGroupItemValue:(BOOL)value_ {
	[self setIsGroupItem:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsGroupItemValue {
	NSNumber *result = [self primitiveIsGroupItem];
	return [result boolValue];
}

- (void)setPrimitiveIsGroupItemValue:(BOOL)value_ {
	[self setPrimitiveIsGroupItem:[NSNumber numberWithBool:value_]];
}

@dynamic itemType;

@dynamic originalIndex;

- (int32_t)originalIndexValue {
	NSNumber *result = [self originalIndex];
	return [result intValue];
}

- (void)setOriginalIndexValue:(int32_t)value_ {
	[self setOriginalIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveOriginalIndexValue {
	NSNumber *result = [self primitiveOriginalIndex];
	return [result intValue];
}

- (void)setPrimitiveOriginalIndexValue:(int32_t)value_ {
	[self setPrimitiveOriginalIndex:[NSNumber numberWithInt:value_]];
}

@dynamic sortDescriptors;

@dynamic title;

@dynamic children;

- (NSMutableSet*)childrenSet {
	[self willAccessValueForKey:@"children"];

	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"children"];

	[self didAccessValueForKey:@"children"];
	return result;
}

@dynamic parent;

@end

