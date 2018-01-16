//
//  ViewController.m
//  CtDBDemo
//
//  Created by Clint on 2018/1/16.
//  Copyright © 2018年 Clint. All rights reserved.
//

#import "ViewController.h"
#import "TestModel.h"
#import "CtDB.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self showForDB];
}

- (void)showForDB {
    CtDB * ctDB = [CtDB shareDB];
    
    NSMutableArray * datas = [NSMutableArray arrayWithCapacity:42];
    for (NSInteger index = 0; index < 10; index++) {
        TestModel * testModel = [[TestModel alloc]init];
        testModel.a = 100;
        testModel.b = @"test";
        [datas addObject:testModel];
    }
    [ctDB insertTableWithData:datas];
    
    NSArray * searchData = [ctDB selectTable:[TestModel class] keys:nil cons:nil ords:nil];
    NSLog(@"%@", searchData);
    
    [ctDB updateTable:[TestModel class] sets:@[set_i(@"a", 150)] cons:@[con_t(@"b", Con_Equal, @"test")]];
    NSArray * updateData = [ctDB selectTable:[TestModel class] keys:nil cons:nil ords:nil];
    NSLog(@"%@", updateData);
    
    [ctDB deleteTable:[TestModel class] cons:@[con_i(@"_id", Con_Equal, 1)]];
    NSArray * deleteData = [ctDB selectTable:[TestModel class] keys:nil cons:nil ords:nil];
    NSLog(@"%@", deleteData);
    
}


@end
