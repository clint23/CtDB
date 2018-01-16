//
//  CtDB.m
//  TestPr
//
//  Created by Clint on 2018/1/13.
//  Copyright © 2018年 Clint. All rights reserved.
//

#import "CtDB.h"

@interface CtDB()

@property (strong, nonatomic) NSMutableDictionary * tableColumns;

@end

@implementation CtDB

#pragma mark - 单例相关
static CtDB * _instance;

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t once_t;
    dispatch_once(&once_t, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

+ (instancetype)shareDB {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    _instance.tableColumns = [NSMutableDictionary dictionaryWithCapacity:42];
    NSArray<NSString *> * tableNames = [_instance exportAllTableName];
    [tableNames enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary * columns = [_instance exportAllPropertyAndType:NSClassFromString(obj)];
        [_instance.tableColumns setObject:columns forKey:obj];
    }];
    return _instance;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    return _instance;
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return _instance;
}

#pragma mark - 数据库操作

- (BOOL)open {
    int result = sqlite3_open([[self dbPath] UTF8String], &_database);
    return (result == SQLITE_OK);
}

- (NSString *)dbPath {
    NSString * document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [document stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
}

- (BOOL)deleteTable:(Class)cla cons:(NSArray<NSString *> *)cons {
    BOOL result = false;
    if ([self createTableWithClass:cla]) {
        NSMutableString * sql = [NSMutableString stringWithFormat:@"delet from %@", NSStringFromClass(cla)];
        if (cons) {
            if (cons.count > 0) {
                [sql appendFormat:@" where %@", [cons componentsJoinedByString:@" and "]];
            }
        }
        int exec_result = sqlite3_exec(_database, sql.UTF8String, NULL, NULL, NULL);
        result = (exec_result == SQLITE_OK);
    }
    return result;
}

- (BOOL)updateTable:(Class)cla sets:(NSArray<NSString *> *)sets cons:(NSArray<NSString *> *)cons {
    BOOL result = false;
    if ([self createTableWithClass:cla]) {
        NSMutableString * sql = [NSMutableString stringWithFormat:@"update %@", NSStringFromClass(cla)];
        if (sets) {
            if (sets.count > 0) {
                [sql appendFormat:@" set %@", [sets componentsJoinedByString:@", "]];
            }
        }
        if (cons) {
            if (cons.count > 0) {
                [sql appendFormat:@" where %@", [cons componentsJoinedByString:@" and "]];
            }
        }
        int exec_result = sqlite3_exec(_database, sql.UTF8String, NULL, NULL, NULL);
        result = (exec_result == SQLITE_OK);
    }
    return result;
}

- (NSArray *)selectTable:(Class)cla keys:(NSArray<NSString *> *)keys cons:(NSArray<NSString *> *)cons ords:(NSArray<NSString *> *)ords {
    NSMutableArray * result = [NSMutableArray arrayWithCapacity:42];
    
    if ([self createTableWithClass:cla]) {
        NSString * key_mess = @"*";
        if (keys) {
            key_mess = [keys componentsJoinedByString:@", "];
        }
        NSMutableString * sql = [NSMutableString stringWithFormat:@"select %@ from %@", key_mess, NSStringFromClass(cla)];
        if (cons) {
            if (cons.count > 0) {
                [sql appendFormat:@" where %@", [cons componentsJoinedByString:@" and "]];
            }
        }
        if (ords) {
            if (ords.count > 0) {
                [sql appendFormat:@" order by %@", [ords componentsJoinedByString:@", "]];
            }
        }
        sqlite3_stmt * stmt;
        int prepare_result = sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, NULL);
        if (prepare_result == SQLITE_OK) {
            NSMutableDictionary * indexKeys = [NSMutableDictionary dictionaryWithCapacity:42];
            NSDictionary * columns = _tableColumns[NSStringFromClass(cla)];
            
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                id tmpObj = [[cla alloc]init];
                if (indexKeys.allKeys.count == 0) {
                    int columnNum = sqlite3_column_count(stmt);
                    for (NSInteger index = 0; index < columnNum; index++) {
                        [indexKeys setValue:@(index) forKey:[NSString stringWithUTF8String:sqlite3_column_name(stmt, (int)index)]];
                    }
                    if ([indexKeys objectForKey:@"_id"]) {
                        if ([cla conformsToProtocol:@protocol(CtDBProtocol)]) {
                            NSString * primaryKey = [((id<CtDBProtocol>)tmpObj) indexKey];
                            [indexKeys setValue:indexKeys[@"_id"] forKey:primaryKey];
                        }
                        [indexKeys removeObjectForKey:@"_id"];
                    }
                }
                NSArray * indexs = indexKeys.allKeys;
                for (NSInteger index = 0; index < indexs.count; index++) {
                    ColumnType type = [columns[indexs[index]] intValue];
                    switch (type) {
                        case Column_Int: {
                            [tmpObj setValue:@(sqlite3_column_int(stmt, [indexKeys[indexs[index]] intValue])) forKey:indexs[index]];
                        }break;
                        case Column_Text: {
                            if (sqlite3_column_text(stmt, [indexKeys[indexs[index]] intValue]) != nil) {
                                [tmpObj setValue:[NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, [indexKeys[indexs[index]] intValue])] forKey:indexs[index]];
                            }
                            
                            
                        } break;
                        case Column_Double: {
                            [tmpObj setValue:@(sqlite3_column_double(stmt, [indexKeys[indexs[index]] intValue])) forKey:indexs[index]];
                        } break;
                        default:
                            break;
                    }
                }
                [result addObject:tmpObj];
            }
        }
    }
    return result;
}

- (BOOL)insertTableWithData:(NSArray *)data {
    BOOL result = true;
    if (data.count > 0) {
        if ([self createTableWithClass:[data[0] class]]) {
            NSString * tableName = NSStringFromClass([data[0] class]);
            NSDictionary * columns = _tableColumns[tableName];
            NSArray<NSString *> * realColumns = [self exportAllTableColumn:tableName];
            NSArray<NSString *> * keys = columns.allKeys;
            
            NSMutableDictionary * textDict = [NSMutableDictionary dictionaryWithCapacity:42];
            NSMutableDictionary * intDict = [NSMutableDictionary dictionaryWithCapacity:42];
            NSMutableDictionary * doubleDict = [NSMutableDictionary dictionaryWithCapacity:42];
            
            NSMutableArray<NSString *> * places = [NSMutableArray arrayWithObject:@"?"];
            [keys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
                switch ([columns[key] intValue]) {
                    case Column_Text: {
                        [textDict setObject:@([realColumns indexOfObject:key] + 1) forKey:key];
                    } break;
                    case Column_Int: {
                        [intDict setObject:@([realColumns indexOfObject:key] + 1) forKey:key];
                    } break;
                    case Column_Double: {
                        [doubleDict setObject:@([realColumns indexOfObject:key] + 1) forKey:key];
                    } break;
                    default:
                        break;
                }
                [places addObject:@"?"];
            }];
            if (sqlite3_exec(_database, "begin", NULL, NULL, NULL) == SQLITE_OK) {
                sqlite3_stmt *stmt;
                NSString * sql = [NSString stringWithFormat:@"insert into %@ values (%@)", NSStringFromClass([data[0] class]), [places componentsJoinedByString:@","]];
                sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, 0);
                
                [data enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [textDict enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull textKey, NSNumber *  _Nonnull index, BOOL * _Nonnull stop) {
                        sqlite3_bind_text(stmt, index.intValue, [[obj valueForKey:textKey] UTF8String], (int)strlen([[obj valueForKey:textKey] UTF8String]), NULL);
                    }];
                    [intDict enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull intKey, NSNumber *  _Nonnull index, BOOL * _Nonnull stop) {
                        sqlite3_bind_int(stmt, index.intValue, [[obj valueForKey:intKey] intValue]);
                    }];
                    [doubleDict enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull doubleKey, NSNumber *  _Nonnull index, BOOL * _Nonnull stop) {
                        sqlite3_bind_double(stmt, index.intValue, [[obj valueForKey:doubleKey] doubleValue]);
                    }];
                    sqlite3_step(stmt);
                    sqlite3_reset(stmt);
                }];
                sqlite3_finalize(stmt);
                result = (sqlite3_exec(_database, "commit", NULL, NULL, NULL) == SQLITE_OK);
            }else {
                result = false;
            }
        }
        
    }
    return result;
}

- (BOOL)createTableWithClass:(Class)cla {
    BOOL result = true;
    if ([_tableColumns.allKeys indexOfObject:NSStringFromClass(cla)] == NSNotFound) {
        BOOL open = [self open];
        if (open) {
            NSArray * allProperty = [self exportAllProperty:cla];
            NSString * sql = [NSString stringWithFormat:@"create table if not exists %@ (_id integer primary key autoincrement, %@)", NSStringFromClass(cla), [allProperty componentsJoinedByString:@", "]];
            int exec_result = sqlite3_exec(_database, sql.UTF8String, NULL, NULL, NULL);
            result = (exec_result == SQLITE_OK);
            if (result) {
                NSDictionary * columns = [self exportAllPropertyAndType:cla];
                [_tableColumns setObject:columns forKey:NSStringFromClass(cla)];
            }
        }else {
            result = false;
        }
    }else {
        result = [self open];
        
        NSArray<NSString *> * allColumn = [self exportAllTableColumn:NSStringFromClass(cla)];
        NSArray<NSString *> * allProperty = [self exportAllProperty:cla];
        
        BOOL change = false;
        NSArray<NSString *> * addColumn = [allProperty filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", allColumn]];
        if (addColumn.count > 0) {
            change = true;
            [addColumn enumerateObjectsUsingBlock:^(NSString * _Nonnull column, NSUInteger idx, BOOL * _Nonnull stop) {
                if (![column isEqualToString:@"_id"]) {
                    NSString * sql = [NSString stringWithFormat:@"alter table %@ add column %@", NSStringFromClass(cla), column];
                    sqlite3_exec(_database, sql.UTF8String, NULL, NULL, NULL);
                }
            }];
        }
        
        NSArray<NSString *> * cutColumn = [allColumn filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", allProperty]];
        if (cutColumn.count > 1) {
            change = true;
            NSString * copySql = [NSString stringWithFormat:@"create table _tmp as select _id, %@ from %@", [allProperty componentsJoinedByString:@", "], NSStringFromClass(cla)];
            if (sqlite3_exec(_database, copySql.UTF8String, NULL, NULL, NULL) == SQLITE_OK) {
                
                [self dropTable:NSStringFromClass(cla)];
                
                NSString * renameSql = [NSString stringWithFormat:@"alter table _tmp rename to %@", NSStringFromClass(cla)];
                sqlite3_exec(_database, renameSql.UTF8String, NULL, NULL, NULL);
            }
        }
        
        _tableColumns = [NSMutableDictionary dictionaryWithCapacity:42];
        NSArray<NSString *> * tableNames = [self exportAllTableName];
        [tableNames enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary * columns = [self exportAllPropertyAndType:NSClassFromString(obj)];
            [_tableColumns setObject:columns forKey:obj];
        }];
    }
    return result;
}

- (BOOL)dropTable:(NSString *)name {
    if ([self open]) {
        NSString * sql = [NSString stringWithFormat:@"drop table if exists %@", name];
        return (sqlite3_exec(_database, sql.UTF8String, NULL, NULL, NULL) == SQLITE_OK);
    }
    return false;
}

- (NSArray<NSString *> *)exportAllTableColumn:(NSString *)tableName {
    NSMutableArray * array = [NSMutableArray arrayWithCapacity:42];
    if ([self open]) {
        NSString * sql = [NSString stringWithFormat:@"PRAGMA table_info([%@])", tableName];
        sqlite3_stmt * stmt;
        int prepare_result = sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, NULL);
        if (prepare_result == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                NSString * columnName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 1)];
                [array addObject:columnName];
            }
        }
    }
    
    return array;
}

- (NSArray<NSString *> *)exportAllTableName {
    NSMutableArray * array = [NSMutableArray arrayWithCapacity:42];
    if([self open]) {
        NSString * sql = @"select name from sqlite_master";
        sqlite3_stmt * stmt;
        int prepare_result = sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, NULL);
        if (prepare_result == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                NSString * tableName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)];
                if (!([tableName isEqualToString:@"sqlite_sequence"])) {
                    [array addObject:tableName];
                }
            }
        }
    }
    
    return array;
}

- (NSArray<NSString *> *)exportAllProperty:(Class)cla {
    u_int count;
    objc_property_t * properties  = class_copyPropertyList(cla, &count);
    NSArray<NSString *> * exceptData = @[@"superclass", @"description", @"debugDescription", @"hash"];
    NSMutableArray<NSString *> * keys = [NSMutableArray arrayWithCapacity:42];
    for (NSInteger index = 0; index < count; index++) {
        NSString * propertyName = [NSString stringWithUTF8String:property_getName(properties[index])];
        if ([exceptData indexOfObject:propertyName] == NSNotFound) {
            [keys addObject:[NSString stringWithUTF8String:property_getName(properties[index])]];
        }
    }
    return keys;
}

- (NSDictionary *)exportAllPropertyAndType:(Class)cla {
    u_int count;
    objc_property_t * properties  = class_copyPropertyList(cla, &count);
    
    NSMutableArray<NSString *> * keys = [NSMutableArray arrayWithCapacity:42];
    for (NSInteger index = 0; index < count; index++) {
        [keys addObject:[NSString stringWithUTF8String:property_getName(properties[index])]];
    }
    
    NSMutableDictionary * columns = [NSMutableDictionary dictionaryWithCapacity:42];
    Ivar * ivars = class_copyIvarList(cla, &count);
    for (NSInteger index = 0; index < count; index++) {
        NSString * ivarName = [NSString stringWithUTF8String:ivar_getName(ivars[index])];
        if ([ivarName hasPrefix:@"_"]) {
            NSString * lessIvarName = [ivarName substringFromIndex:1];
            ColumnType type = [self transType:[NSString stringWithUTF8String:ivar_getTypeEncoding(ivars[index])]];
            if ([keys indexOfObject:lessIvarName] != NSNotFound) {
                [columns setObject:[NSNumber numberWithInt:type] forKey:lessIvarName];
            }
        }
    }
    
    return columns;
}


NSString * con_t(NSString * key, ConType type, NSString * value) {
    NSArray * type_value = @[@">", @"=", @"<", @">=", @"<"];
    return [NSString stringWithFormat:@"%@ %@ '%@'", key, type_value[type], value];
}

NSString * con_i(NSString * key, ConType type, NSInteger value) {
    NSArray * type_value = @[@">", @"=", @"<", @">=", @"<"];
    return [NSString stringWithFormat:@"%@ %@ %ld", key, type_value[type], value];
}

NSString * con_d(NSString * key, ConType type, CGFloat value) {
    NSArray * type_value = @[@">", @"=", @"<", @">=", @"<"];
    return [NSString stringWithFormat:@"%@ %@ %f", key, type_value[type], value];
}

NSString * ord(NSString * key, OrdType type) {
    NSArray * type_value = @[@"asc", @"desc"];
    return [NSString stringWithFormat:@"%@ %@", key, type_value[type]];
}

NSString * set_t(NSString * key, NSString * value) {
    return [NSString stringWithFormat:@"%@ = '%@'", key, value];
}

NSString * set_i(NSString * key, NSInteger value) {
    return [NSString stringWithFormat:@"%@ = %ld", key, value];
}

NSString * set_d(NSString * key, CGFloat value) {
    return [NSString stringWithFormat:@"%@ = %f", key, value];
}


- (ColumnType)transType:(NSString *)type {
    ColumnType result = Column_Text;

    NSArray * types = @[@"@\"NSString\"", @"d", @"f", @"i", @"s", @"l", @"q", @"I", @"S", @"L", @"Q", @"c", @"C"];
    switch ([types indexOfObject:type]) {
        case 0: {
            result = Column_Text; }break;
        case 1: {
            result = Column_Double; } break;
        case 2: {
            result = Column_Double; } break;
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
        case 10: {
            result = Column_Int; }break;
        case 11:
        case 12: {
            result = Column_Text; } break;
        default: {
            result = Column_Text; } break;
    }
            return result;
}

@end
