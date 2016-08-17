//
//  DB.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import SQLite  // using SQLite.swift https://github.com/stephencelis/SQLite.swift
import UIKit
import JSONJoy
import MapKit
import CoreLocation

//# Caching
//
// The app tries to cache the PokeAPI RESTful responses in a local SQLite database, however even so it states in the
// official documentation for version 2 of the API the modified/created timestamps are only avaiable in version 1.
//
//> If you are going to be regularly using the API, I recommend caching data on your service.
//> Luckily, we provide modified/created datetime stamps on every single resource so you can check for updates
//> (and thus make your caching efficient).
//    
//    
// See this issue on github for details: https://github.com/phalt/pokeapi/issues/140
//

private let DB_FILENAME: String = (applicationDocumentsFolder() as NSString).stringByAppendingPathComponent("pokedb.sqlite3")

private let API_VERSION: Int = 2
private let APP_VERSION: Int = 1

// NOTE(dkg): maybe put the table names in an array, and use the array values
//            as key into a Map/HashMap for a list of columns
//            instead of all these constants
private let TABLE_API_CACHE                         = "api_cache"

private let TABLE_API_CACHE_COLUMN_ID               = "id"
private let TABLE_API_CACHE_COLUMN_REQ_ID           = "requestId"
private let TABLE_API_CACHE_COLUMN_API_TYPE         = "apiType"
private let TABLE_API_CACHE_COLUMN_JSON_RESPONSE    = "jsonResponse"
private let TABLE_API_CACHE_COLUMN_QUERY_PARAMETERS = "queryParameters"
private let TABLE_API_CACHE_COLUMN_LAST_UPDATED     = "lastUpdated"
private let TABLE_API_CACHE_COLUMN_API_VERSION      = "apiVersion"
private let TABLE_API_CACHE_COLUMN_APP_VERSION      = "appVersion"


private let TABLE_POKEMON                   = "pokemon"

private let TABLE_POKEMON_COLUMN_ID         = "id"
private let TABLE_POKEMON_COLUMN_NAME       = "name"
private let TABLE_POKEMON_COLUMN_WEIGHT     = "weight"
private let TABLE_POKEMON_COLUMN_HEIGHT     = "height"
private let TABLE_POKEMON_COLUMN_FAVORITE   = "favorite"
private let TABLE_POKEMON_COLUMN_STARS      = "stars"     // TODO(dkg): actual use this
private let TABLE_POKEMON_COLUMN_COMMENT    = "comment"   // TODO(dkg): actual use this


private let TABLE_BACKPACK                   = "backpack"

private let TABLE_BACKPACK_COLUMN_ID         = "id"
private let TABLE_BACKPACK_COLUMN_POKEMON_ID = "pokemon_id"
private let TABLE_BACKPACK_COLUMN_FOUND_LAT  = "foundlat"
private let TABLE_BACKPACK_COLUMN_FOUND_LONG = "foundlong"
private let TABLE_BACKPACK_COLUMN_FOUND_DATE = "founddate"
private let TABLE_BACKPACK_COLUMN_NAME       = "name"   // TODO(dkg): implement user can rename the pokemon



public let API_LIST_REQUEST_ID = -1 // whenever we want to cache the result of a "list" request, we use this ID

public enum APIType: String {
    // NOTE(dkg): list access to API endpoint (name same as endpoint but without "list-" prefix)
    case ListPokemon = "list-pokemon"
    // NOTE(dkg): official API endpoints names - use this for individual ID/name access
    // TODO(dkg): add more
    case Pokemon = "pokemon"
    case PokemonForm = "pokemon-form"
    case PokemonSpecies = "pokemon-species"
    case Move = "move"
}

public final class DB {
 
    let db: Connection
    
    //
    // MARK: Init
    //
    init() {
        db = try! Connection(DB_FILENAME)
        log("DB_FILENAME \(DB_FILENAME)")
    }
    
    //
    // MARK: Create Tables
    //
    public func createTables() {
        log("Create tables....")
        createCacheTable()
        createPokemonTable()
        createBackpackTable()
    }
    
    // TODO(dkg): refactor common table creation/statement execution code
    private func createCacheTable() {
        do {
            // a table to cache ALL RESTful API calls; not the best solution, but the quickest to implement
            // one could use a cache table for each individual API endpoint instead, but that's obviously more work
            
            // independent PK
            let col0 = "\(TABLE_API_CACHE_COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT"
            
            // the actual resource ID used in the request, so this is not unique on its own
            let col1 = "\(TABLE_API_CACHE_COLUMN_REQ_ID) INTEGER NOT NULL"
            
            // the RESTful API resource that was requested
            let col2 = "\(TABLE_API_CACHE_COLUMN_API_TYPE) TEXT NOT NULL"
            
            // the actual JSON response from the server
            let col3 = "\(TABLE_API_CACHE_COLUMN_JSON_RESPONSE) TEXT"
            
            // for list requests, the query parameters used in the request: eg "?limit=10&offset=0"
            let col4 = "\(TABLE_API_CACHE_COLUMN_QUERY_PARAMETERS) TEXT"
            
            // API responses are cached for 24 hours (or maybe make this a configuration option?)
            let col5 = "\(TABLE_API_CACHE_COLUMN_LAST_UPDATED) DATETIME NOT NULL DEFAULT NOW"
            
            let col6 = "\(TABLE_API_CACHE_COLUMN_API_VERSION) INTEGER NOT NULL DEFAULT \(API_VERSION)"
            let col7 = "\(TABLE_API_CACHE_COLUMN_APP_VERSION) INTEGER NOT NULL DEFAULT \(APP_VERSION)"
            
            let sql = "CREATE TABLE IF NOT EXISTS \(TABLE_API_CACHE) (" +
                "\(col0), " +
                "\(col1), " +
                "\(col2), " +
                "\(col3), " +
                "\(col4), " +
                "\(col5), " +
                "\(col6), " +
                "\(col7)" +
            ")"
            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            logWarn("ERROR: Could not run SQL statement: \(error)")
        }
    }
    
    private func createPokemonTable() {
        do {
            // the actual resource ID from the API for the pokemon
            let col0 = "\(TABLE_POKEMON_COLUMN_ID) INTEGER PRIMARY KEY NOT NULL"
            
            let col1 = "\(TABLE_POKEMON_COLUMN_NAME) TEXT NOT NULL"
            let col2 = "\(TABLE_POKEMON_COLUMN_WEIGHT) INT NOT NULL DEFAULT 0"
            let col3 = "\(TABLE_POKEMON_COLUMN_HEIGHT) INT NOT NULL DEFAULT 0"
            let col4 = "\(TABLE_POKEMON_COLUMN_STARS) TINYINT NOT NULL DEFAULT 0"
            let col5 = "\(TABLE_POKEMON_COLUMN_FAVORITE) TINYINT NOT NULL DEFAULT 0"
            let col6 = "\(TABLE_POKEMON_COLUMN_COMMENT) TEXT"
            
            let sql = "CREATE TABLE IF NOT EXISTS \(TABLE_POKEMON) (" +
                "\(col0), " +
                "\(col1), " +
                "\(col2), " +
                "\(col3), " +
                "\(col4), " +
                "\(col5), " +
                "\(col6) " +
            ")"
            
            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            log("ERROR: Could not run SQL statement: \(error)")
        }
    }

    private func createBackpackTable() {
        do {
            
            let col0 = "\(TABLE_BACKPACK_COLUMN_ID) INTEGER PRIMARY KEY AUTOINCREMENT"
            
            let col1 = "\(TABLE_BACKPACK_COLUMN_POKEMON_ID) INTEGER NOT NULL"
            let col2 = "\(TABLE_BACKPACK_COLUMN_FOUND_LAT) FLOAT DEFAULT 0"
            let col3 = "\(TABLE_BACKPACK_COLUMN_FOUND_LONG) FLOAT DEFAULT 0"
            let col4 = "\(TABLE_BACKPACK_COLUMN_FOUND_DATE) DATETIME DEFAULT NOW"
            let col5 = "\(TABLE_BACKPACK_COLUMN_NAME) TEXT"
            
            let sql = "CREATE TABLE IF NOT EXISTS \(TABLE_BACKPACK) (" +
                "\(col0), " +
                "\(col1), " +
                "\(col2), " +
                "\(col3), " +
                "\(col4), " +
                "\(col5), " +
                "FOREIGN KEY(\(TABLE_BACKPACK_COLUMN_POKEMON_ID)) REFERENCES \(TABLE_POKEMON)(\(TABLE_POKEMON_COLUMN_ID))" +
            ")"
            
            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            logWarn("ERROR: Could not run SQL statement: \(error)")
        }
    }
    
    //
    // MARK: Public Interface
    //
    // TODO(dkg): improve error handling/reporting
    public func insertOrUpdateCachedResponse(type: APIType, json: String, requestId: Int = API_LIST_REQUEST_ID,
                                             queryParameters: String?, lastUpdated: NSDate = NSDate()) -> Void {

        let apiCacheTable = Table(TABLE_API_CACHE)

        let requestIdColumn = Expression<Int>(TABLE_API_CACHE_COLUMN_REQ_ID)
        let apiTypeColumn = Expression<String>(TABLE_API_CACHE_COLUMN_API_TYPE)
        let jsonColumn = Expression<String?>(TABLE_API_CACHE_COLUMN_JSON_RESPONSE)
        let queryParamsColumn = Expression<String?>(TABLE_API_CACHE_COLUMN_QUERY_PARAMETERS)
        let lastUpdatedColumn = Expression<NSDate>(TABLE_API_CACHE_COLUMN_LAST_UPDATED)
        
        let query = apiCacheTable
                        .filter(requestIdColumn == requestId)
                        .filter(queryParamsColumn == queryParameters)
                        .filter(apiTypeColumn == type.rawValue)
                        .limit(1)
        
        if db.pluck(query) != nil {
            // update
            let update = query.update(jsonColumn <- json,
                                      queryParamsColumn <- queryParameters,
                                      lastUpdatedColumn <- lastUpdated)
            do {
                let updatedCount = try db.run(update)
                log("updated data: \(updatedCount)")
            } catch {
                log("could not update data: \(error)")
            }
        } else {
            // insert
            let insert = apiCacheTable.insert(requestIdColumn <- requestId,
                                              apiTypeColumn <- type.rawValue,
                                              jsonColumn <- json,
                                              queryParamsColumn <- queryParameters,
                                              lastUpdatedColumn <- lastUpdated)
            do {
                let rowid = try db.run(insert)
                log("inserted data: \(rowid)")
            } catch {
                // TODO(dkg): catch the "database is locked" error and try again after a few milliseconds
                logWarn("could not insert data: \(error)")
            }
        }
    }
    
    
    public func getCachedResponse(type: APIType, requestId: Int = API_LIST_REQUEST_ID, queryParameters: String? = nil) -> String? {
        let apiCacheTable = Table(TABLE_API_CACHE)

        let requestIdColumn = Expression<Int>(TABLE_API_CACHE_COLUMN_REQ_ID)
        let apiTypeColumn = Expression<String>(TABLE_API_CACHE_COLUMN_API_TYPE)
        let jsonColumn = Expression<String?>(TABLE_API_CACHE_COLUMN_JSON_RESPONSE)
        let queryParamsColumn = Expression<String?>(TABLE_API_CACHE_COLUMN_QUERY_PARAMETERS)
        let apiVersionColumn = Expression<Int>(TABLE_API_CACHE_COLUMN_API_VERSION)

        let query = apiCacheTable
                        .filter(requestIdColumn == requestId)
                        .filter(apiTypeColumn == type.rawValue)
                        .filter(queryParamsColumn == queryParameters)
                        .filter(apiVersionColumn == API_VERSION)
                        .limit(1)
        
        let row = db.pluck(query)
        let result = row?.get(jsonColumn)

        return result
    }
    
    
//    public func savePokemon(pokemon: Pokemon, name: String? = nil, favorite: Bool = false, stars: Int = 0, comment: String? = nil) {
//        let pokemonTable = Table("pokemon")
//        let idColumn = Expression<Int>("id")
//        let nameColumn = Expression<String>("name")
//        let favoriteColumn = Expression<Bool>("favorite")
//        let starsColumn = Expression<Int>("stars")
//        let commentColumn = Expression<String>("comment")
//        
//        let query = pokemonTable
//            .filter(idColumn == pokemon.id)
//            .limit(1)
//        
//        let newName = name == nil ? pokemon.name : name!
//        let newComment = comment == nil ? "" : comment!
//        
//        if db.pluck(query) != nil {
//            // update
//            let update = query.update(nameColumn <- newName,
//                                      favoriteColumn <- favorite,
//                                      starsColumn <- stars,
//                                      commentColumn <- newComment)
//            do {
//                let updatedCount = try db.run(update)
//                log("updated pokemon \(pokemon.id) data: \(updatedCount)")
//            } catch {
//                logWarn("could not update pokemon \(pokemon.id) data: \(error)")
//            }
//        } else {
//            // insert
//            let insert = pokemonTable.insert(idColumn <- pokemon.id,
//                                             nameColumn <- newName,
//                                             favoriteColumn <- favorite,
//                                             starsColumn <- stars,
//                                             commentColumn <- newComment)
//            do {
//                let rowid = try db.run(insert)
//                log("inserted pokemon \(pokemon.id) data: \(rowid)")
//            } catch {
//                logWarn("could not insert pokemon \(pokemon.id) data: \(error)")
//            }
//        }
//    }
    
//    public func getPokemonJSON(pokemonId: Int) -> String? {
//        return getCachedResponse(.Pokemon, id: pokemonId)
//    }

//    public func updatePokemonFavoriteStatus(pokemonId: Int, isFavorite: Bool) {
//
//        let pokemonTable = Table("pokemon")
//        let idColumn = Expression<Int>("id")
//        let favoriteColumn = Expression<Bool>("favorite")
//        
//        let query = pokemonTable
//            .filter(idColumn == pokemonId)
//            .limit(1)
//
//        if db.pluck(query) != nil {
//            // update
//            let update = query.update(favoriteColumn <- isFavorite)
//            do {
//                let updatedCount = try db.run(update)
//                log("updated pokemon \(pokemonId) data: \(updatedCount)")
//            } catch {
//                logWarn("could not update pokemon \(pokemonId) data: \(error)")
//            }
//        }
//    }

//    public func isPokemonFavorite(pokemonId: Int) -> Bool {
//        let pokemonTable = Table("pokemon")
//        let idColumn = Expression<Int>("id")
//        let favoriteColumn = Expression<Bool>("favorite")
//        
//        let query = pokemonTable.select(favoriteColumn)
//                                .filter(idColumn == pokemonId)
//        let row = db.pluck(query)
//        
//        return (row?.get(favoriteColumn))!
//    }

//    public func loadPokemons() -> [Pokemon] {
//    public func loadPokemons(limit: Int = 0) -> [String] {
//        log("loadPokemons() start")
//        let pokemonTable = Table("pokemon")
//        let apiCacheTable = Table("api_cache")
//        let nameColumn = Expression<String>("name")
//        let pokemonIdColumn = Expression<Int>("id")
//        let idColumn = Expression<Int>("id")
//        let jsonColumn = Expression<String>("jsonResponse")
//        let apiTypeColumn = Expression<String>("apiType")
//        
//        let joinQuery = pokemonTable.join(apiCacheTable, on: apiCacheTable[idColumn] == pokemonTable[pokemonIdColumn])
//                                    .filter(apiTypeColumn == APIType.Pokemon.rawValue)
//                                    .order(nameColumn)
//        let query = joinQuery.select(jsonColumn).order(nameColumn)
////        let query = joinQuery.select(pokemonTable[pokemonIdColumn]).order(nameColumn)
//        
//        var rows: AnySequence<Row>? = nil
//        if limit > 0 {
//            rows = try! db.prepare(query.limit(limit))
//        } else {
//            rows = try! db.prepare(query)
//        }
//        
//        // NOTE(dkg): Using the JSONDecoder like this in the loop is really, really slow.
//        //            Especially if we have more than a few Pokemons in the list.
//        
////        var result = [Pokemon]() ==> SLOWEST OF ALL!
////        var result = [Int]() ==> Fastest of all, however then the actual cell drawing/rendering takes longer because
////                                 each cell has to query the db again for the json and then parse it to a Pokemon object.
//        var result = [String]() // middle ground: no need for individual JSON lookup, but needs extra parsing for each cell
//                                // when drawing
//        for row in rows! {
//            // NOTE(dkg): this autoreleasepool has a performance impact, but it also solve the memory pressure
//            //            will need further profiling to figure out what the best course of action would be
//            autoreleasepool({
//            
//                let json = row.get(jsonColumn)
////                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
////                let pokemon = try! Pokemon(JSONDecoder(data))
//                
////                let id: Int = row.get(pokemonTable[pokemonIdColumn])
//
//                // TODO(dkg): Actually replace the name with the custom name the user may have given this pokemon?!
//                //            That is, if we ever figure out how we want this feature to work.
//                //            Or remove this incomplete feature again.
//
////                result.append(pokemon)
//                result.append(json)
//                
//            })
//        }
//        
//        log("loadPokemons() end")
//        
//        return result
//    }
    
//    func loadPokemonsWithFilter(term: String) -> [String] {
//        log("loadPokemonsWithFilter(\(term))")
//        
//        let pokemonTable = Table("pokemon")
//        let apiCacheTable = Table("api_cache")
//        let nameColumn = Expression<String>("name")
//        let pokemonIdColumn = Expression<Int>("id")
//        let idColumn = Expression<Int>("id")
//        let jsonColumn = Expression<String>("jsonResponse")
//        let apiTypeColumn = Expression<String>("apiType")
//        
//        let joinQuery = pokemonTable.join(apiCacheTable, on: apiCacheTable[idColumn] == pokemonTable[pokemonIdColumn])
//                                    .filter(apiTypeColumn == APIType.Pokemon.rawValue)
//                                    .filter(pokemonTable[nameColumn].lowercaseString.like("%\(term.lowercaseString)%"))
//                                    .order(nameColumn)
//        let query = joinQuery.select(jsonColumn)
//        
//        let rows = try! db.prepare(query)
//        
//        var result = [String]()
//        for row in rows {
//            let json = row.get(jsonColumn)
//            result.append(json)
//        }
//        
//        return result
//    }
//    
    
//    public func loadFavoritePokemons() -> [Pokemon] {
//        log("loadFavoritePokemons() start")
//
//        let pokemonTable = Table("pokemon")
//        let apiCacheTable = Table("api_cache")
//        let nameColumn = Expression<String>("name")
//        let pokemonIdColumn = Expression<Int>("id")
//        let idColumn = Expression<Int>("id")
//        let favoriteColumn = Expression<Bool>("favorite")
//        let jsonColumn = Expression<String>("jsonResponse")
//        let apiTypeColumn = Expression<String>("apiType")
//        
//        let joinQuery = pokemonTable.join(apiCacheTable, on: apiCacheTable[idColumn] == pokemonTable[pokemonIdColumn])
//                                    .filter(apiTypeColumn == APIType.Pokemon.rawValue)
//                                    .filter(favoriteColumn == true)
//                                    .order(nameColumn)
//        let query = joinQuery.select(jsonColumn)
//        
//        let rows = try! db.prepare(query)
//        let transformer = Transformer()
//
//        var result = [Pokemon]()
//        for row in rows {
//            autoreleasepool({
//                
//                let json = row.get(jsonColumn)
//                if let pokemon = transformer.jsonToPokemonModel(json) {
//                    result.append(pokemon)
//                }
//            })
//        }
//        
//        log("loadFavoritePokemons() end")
//        
//        return result
//    }
    
    
//    public func savePokemonInBackpack(pokemon: Pokemon, latitude: Double, longitude: Double, name: String? = nil) {
//        let backpackTable = Table("backpack")
//        let pokemonColumn = Expression<Int>("pokemon_id")
//        let latColumn = Expression<Double>("foundlat")
//        let longColumn = Expression<Double>("foundlong")
//        let dateColumn = Expression<NSDate>("founddate")
//        let nameColumn = Expression<String>("name")
//        
//        let newName = name == nil ? pokemon.name : name!
//        
//        // always insert - we can have several pokemons of the same type/name in the backpack
//        let insert = backpackTable.insert(pokemonColumn <- pokemon.id,
//                                          nameColumn <- newName,
//                                          latColumn <- latitude,
//                                          longColumn <- longitude,
//                                          dateColumn <- NSDate())
//        do {
//            let rowid = try db.run(insert)
//            log("inserted pokemon \(pokemon.id) data in backpack: \(rowid)")
//        } catch {
//            logWarn("could not insert pokemon \(pokemon.id) data in backpack: \(error)")
//        }
//    }
//    
//    public func removePokemonFromBackpack(pokemon: Pokemon, caughtOnDate: NSDate) {
//        let backpackTable = Table("backpack")
//        let pokemonColumn = Expression<Int>("pokemon_id")
//        let dateColumn = Expression<NSDate>("founddate")
//        let pokemonRow = backpackTable.filter(pokemonColumn == pokemon.id)
//                                      .filter(dateColumn == caughtOnDate)
//        do {
//            let rowid = try db.run(pokemonRow.delete())
//            log("delete pokemon \(pokemon.id) data from backpack: \(rowid)")
//        } catch {
//            logWarn("could not delete pokemon \(pokemon.id) data from backpack: \(error)")
//        }
//    }
//    
//    public func loadPokemonFromBackpack(pokemonId: Int) -> Pokemon? {
//        let backpackTable = Table("backpack")
//        let pokemonIdColumn = Expression<Int>("pokemon_id")
//        let apiCacheTable = Table("api_cache")
//        let apiTypeColumn = Expression<String>("apiType")
//        let idColumn = Expression<Int>("id")
//        let jsonColumn = Expression<String>("jsonResponse")
//        
//        let joinQuery = backpackTable.join(apiCacheTable, on: apiCacheTable[idColumn] == backpackTable[pokemonIdColumn])
//                                     .filter(apiTypeColumn == APIType.Pokemon.rawValue)
//                                     .filter(backpackTable[pokemonIdColumn] == pokemonId)
//        let query = joinQuery.select(jsonColumn)
//        
//        if let row = db.pluck(query) {
//            return Transformer().jsonToPokemonModel(row.get(jsonColumn))
//        } else {
//            return nil
//        }
//    }
    
//    // TODO(dkg): this is slow when there are a lot of pokemon in the backpack - find a more
//    //            performant way to do this
//    public func loadPokemonsFromBackpackAsPokemonAnnotations() -> [PokemonAnnotation] {
//        log("loadPokemonsFromBackpack() start")
//
//        let backpackTable = Table("backpack")
//        let apiCacheTable = Table("api_cache")
//        let nameColumn = Expression<String>("name")
//        let pokemonIdColumn = Expression<Int>("pokemon_id")
//        let idColumn = Expression<Int>("id")
//        let jsonColumn = Expression<String>("jsonResponse")
//        let apiTypeColumn = Expression<String>("apiType")
//        let latColumn = Expression<Double>("foundlat")
//        let longColumn = Expression<Double>("foundlong")
//        let dateColumn = Expression<NSDate>("founddate")
//        
//        let joinQuery = backpackTable.join(apiCacheTable, on: apiCacheTable[idColumn] == backpackTable[pokemonIdColumn])
//                                     .filter(apiTypeColumn == APIType.Pokemon.rawValue)
//                                     .order(nameColumn)
//        let query = joinQuery.select(jsonColumn, latColumn, longColumn, dateColumn)
//        
//        let rows = try! db.prepare(query)
//        let transformer = Transformer()
//        let dl = Downloader()
//        
//        var result = [PokemonAnnotation]()
//        for row in rows {
//            autoreleasepool({
//                
//                let json = row.get(jsonColumn)
//                if let pokemon = transformer.jsonToPokemonModel(json) {
//                    let lat = row.get(latColumn)
//                    let lon = row.get(longColumn)
//                    let coords: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: lat, longitude: lon)
//                    let image = dl.getPokemonSpriteFromCache(pokemon)
//                    let date = row.get(dateColumn)
//                    let annotation = PokemonAnnotation(coordinate: coords, pokemon: pokemon, image: image, found: date)
//
//                    result.append(annotation)
//                }
//            })
//        }
//        
//        log("loadPokemonsFromBackpack() end")
//        
//        return result
//        
//    }
    
}

