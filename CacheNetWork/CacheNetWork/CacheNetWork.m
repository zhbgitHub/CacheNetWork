//
//  CacheNetWork.m
//  网络数据离线缓存
//
//  Created by SZT on 16/3/21.
//  Copyright © 2016年 SZT. All rights reserved.
//

#import "CacheNetWork.h"
#import "CacheDataBase.h"

@interface CacheNetWork()<NSURLSessionDelegate>

@end


static CacheNetWork *cacheNetWork = nil;

@implementation CacheNetWork


+ (CacheNetWork *)shareCacheNetWork
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheNetWork = [[CacheNetWork alloc]init];
        cacheNetWork.myCache = [[NSCache alloc]init];
    });
    return cacheNetWork;
}



/**
 *  普通get请求，支持内存缓存，沙盒缓存
 *
 *  @param data     请求到的data数据
 *  @param response 响应头
 *  @param error    请求出错时包含的错误信息
 *
 *  @return
 */
+ (void)getWithUrlString:(NSString *)urlString  completionHandler:(requessSucceed)completionBlock
{
    CacheNetWork *CNK = [CacheNetWork shareCacheNetWork];
    NSDictionary *dataDict = [CNK.myCache objectForKey:urlString];
    if (dataDict) {

        [self doingCompletionBlock:completionBlock WithDict:dataDict];
        
    }else{
        
        NSDictionary *fileDict = [CacheDataBase selectDictWithUrlString:urlString];
        if (fileDict) {

            [self doingCompletionBlock:completionBlock WithDict:fileDict];
            
        }else{
            NSURLSessionConfiguration *sessionConfigure = [NSURLSessionConfiguration defaultSessionConfiguration];
            
            NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfigure delegate:CNK delegateQueue:[NSOperationQueue mainQueue]];
            
            NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"请求出错：%@",error);
                }else{
                    //请求成功后将数据存入到缓存中
                    NSDictionary *cacheDict = @{@"data":data,@"response":response};
                    [CNK.myCache setObject:cacheDict forKey:urlString];
                    
                    //存储到沙盒中
                    [CacheDataBase insertDict:cacheDict WithMainKey:urlString];
                    
                    //执行block
                    completionBlock(data,response,error);
                    NSLog(@"%@",[NSThread currentThread]);
                    
                }
            }];
            [task resume];
        }
    }
}

/**
 *  普通post请求
 *
 *  @param data     请求得到数据
 *  @param response 请求得到响应头
 *  @param error    请求出错时包含的错误信息
 *
 *  @return
 */
+ (void)postWithUrlString:(NSString *)urlString  parameter:(NSDictionary *)dict completionhandler:(requessSucceed)completionBlock
{
    CacheNetWork *CNK = [CacheNetWork shareCacheNetWork];
    NSDictionary *dataDict = [CNK.myCache objectForKey:urlString];
    if (dataDict) {//判断缓存中是否有数据
        
        [self doingCompletionBlock:completionBlock WithDict:dataDict];
        
    }else{
        NSDictionary *fileDict = [CacheDataBase selectDictWithUrlString:urlString];
        if (fileDict) {
            
            [self doingCompletionBlock:completionBlock WithDict:fileDict];
            
        }else{
            NSURLSession *session = [NSURLSession sharedSession];
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url];
            request.HTTPMethod = @"POST";
            NSMutableString *httpMethod = [NSMutableString new];
            for (NSString *key in dict.allKeys) {
                NSString *value = dict[key];
                [httpMethod appendFormat:@"&%@=%@",key,value];
            }
            request.HTTPBody = [[httpMethod substringFromIndex:1] dataUsingEncoding:NSUTF8StringEncoding];
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                
                if (error) {
                    NSLog(@"请求失败:%@",error);
                }else{
                    //请求成功后将数据存入到缓存中
                    NSDictionary *cacheDict = @{@"data":data,@"response":response};
                    [CNK.myCache setObject:cacheDict forKey:urlString];
                    
                    //同时存储到沙盒当中
                    [CacheDataBase insertDict:cacheDict WithMainKey:urlString];
                    //执行block
                    completionBlock(data,response,error);
                }
                
            }];
            [task resume];
        }
    }
}


/**
 *  将字典dict中的数据获取出来并且作为block的参数执行block
 *
 *  @param succeed 要执行的block
 *  @param dict    字典
 */
+ (void)doingCompletionBlock:(requessSucceed)succeed WithDict:(NSDictionary *)dict
{
    NSData *data = dict[@"data"];
    NSURLResponse *response = dict[@"response"];
    NSError *error = dict[@"error"];
    succeed(data,response,error);
}


+ (void)clearSandBoxCache
{
    [CacheDataBase deleteAllData];
}


@end
