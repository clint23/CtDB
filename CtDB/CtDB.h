//
//  CtDB.h
//  TestPr
//
//  Created by Clint on 2018/1/13.
//  Copyright © 2018年 Clint. All rights reserved.
//
//  基于model的sqlite3操作库，model变化时对应的数据表将自动增添，删除字段

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>


@protocol CtDBProtocol <NSObject>

- (NSString *)indexKey;

@end


/**
 数据库操作类，内部基于sqlite3进行数据库操作，数据库表操作需要严格对应一表一模型的原则
 */
@interface CtDB : NSObject{
    sqlite3 * _database;
}

/** 类型枚举值，数据库只将数据保存为以下类型 */
typedef NS_ENUM(NSInteger, ColumnType) {
    Column_Text,
    Column_Double,
    Column_Int
};


/** 条件枚举值 */
typedef NS_ENUM(NSInteger, ConType) {
    Con_Big,
    Con_Equal,
    Con_Small,
    Con_BigE,
    Con_SmallE
};


/** 排序枚举值 */
typedef NS_ENUM(NSInteger, OrdType) {
    Ord_Asc,
    Ord_Desc
};

/** 使用本单例方法进行初始化 */
+ (instancetype)shareDB;


/**
 查询函数

 @param cla 要操作的数据表对应的类，数据表名与类型相同
 @param keys 要获取的key列表，如为null，则获取所有key
 @param cons 条件表达式列表，可使用con_t，con_i，con_d编写
 @param ords 排序表达式列表，可使用ord编写
 @return 查询结果，结果将自动模型化
 */
- (NSArray *)selectTable:(Class)cla keys:(NSArray<NSString *> *)keys
                    cons:(NSArray<NSString *> *)cons
                    ords:(NSArray<NSString *> *)ords;


/**
 插入函数

 @warning 为保证插入效率，此函数只支持插入相同类型的数据，
 @param data 要插入的数据
 @return 插入是否成功
 */
- (BOOL)insertTableWithData:(NSArray *)data;


/**
 更新函数

 @param cla 要操作的数据表对应的类，数据表名与类型相同
 @param sets 设置表达式列表，可使用set_t，set_i，set_d编写
 @param cons 条件表达式列表，可使用con_t，con_i，con_d编写
 @return 更新是否成功
 */
- (BOOL)updateTable:(Class)cla
               sets:(NSArray<NSString *> *)sets
               cons:(NSArray<NSString *> *)cons;


/**
 删除函数

 @param cla 要操作的数据表对应的类，数据表名与类型相同
 @param cons 条件表达式列表，可使用con_t，con_i，con_d编写
 @return 删除是否成功
 */
- (BOOL)deleteTable:(Class)cla
               cons:(NSArray<NSString *> *)cons;

/** 获取所有数据库表名，屏蔽了sqlit默认的系统表 */
- (NSArray<NSString *> *)exportAllTableName;


/**
 获取某数据库表的所有列名

 @param tableName 表名
 @return 所有列名组成的数据
 */
- (NSArray<NSString *> *)exportAllTableColumn:(NSString *)tableName;

/** 文本条件表达式 */
NSString * con_t(NSString * key, ConType type, NSString * value);
/** 整型条件表达式 */
NSString * con_i(NSString * key, ConType type, NSInteger value);
/** 浮点型条件表达式 */
NSString * con_d(NSString * key, ConType type, CGFloat value);

/** 排序表达式 */
NSString * ord(NSString * key, OrdType type);

/** 文本设置表达式 */
NSString * set_t(NSString * key, NSString * value);
/** 整型设置表达式 */
NSString * set_i(NSString * key, NSInteger value);
/** 浮点型设置表达式 */
NSString * set_d(NSString * key, CGFloat value);

@end
