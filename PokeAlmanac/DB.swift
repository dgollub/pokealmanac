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
    
    init() {
        db = try! Connection(DB_FILENAME)
        log("DB_FILENAME \(DB_FILENAME)")
    }
    
    public func createTables() {
        log("Create tables....")
        createCacheTable()
        createPokemonTables()
    }
    
    
    // TODO(dkg): improve error handling/reporting
    public func insertOrUpdateCachedResponse(type: APIType, json: String, id: Int = API_LIST_REQUEST_ID, offset: Int = 0, limit: Int = 0, lastUpdated: NSDate = NSDate()) -> Void {

        let apiCacheTable = Table("api_cache")
        let idColumn = Expression<Int>("id")
        let apiTypeColumn = Expression<String>("apiType")
        let jsonColumn = Expression<String>("jsonResponse")
        let lastUpdatedColumn = Expression<NSDate>("lastUpdated")
        let limitColumn = Expression<Int>("listLimit")
        let offsetColumn = Expression<Int>("listOffset")
        let apiVersionColumn = Expression<Int>("apiVersion")
        let appVersionColumn = Expression<Int>("appVersion")
        
        let query = apiCacheTable
            .filter(idColumn == id)
            .filter(apiTypeColumn == type.rawValue)
            .filter(limitColumn == limit)
            .filter(offsetColumn == offset)
            .filter(apiVersionColumn == API_VERSION)
            .limit(1)
        
        if db.pluck(query) != nil {
            // update
            let update = query.update(jsonColumn <- json, lastUpdatedColumn <- lastUpdated)
            do {
                let updatedCount = try db.run(update)
                log("updated data: \(updatedCount)")
            } catch {
                log("could not update data: \(error)")
            }
        } else {
            // insert
            let insert = apiCacheTable.insert(idColumn <- id, apiTypeColumn <- type.rawValue,
                                              limitColumn <- limit, offsetColumn <- offset,
                                              lastUpdatedColumn <- lastUpdated,
                                              appVersionColumn <- APP_VERSION, apiVersionColumn <- API_VERSION,
                                              jsonColumn <- json)
            do {
                let rowid = try db.run(insert)
                log("inserted data: \(rowid)")
            } catch {
                // TODO(dkg): catch the "database is locked" error and try again after a few milliseconds
                logWarn("could not insert data: \(error)")
            }
        }
    }
    
    
    public func getCachedResponse(type: APIType, id: Int = API_LIST_REQUEST_ID, offset: Int = 0, limit: Int = 0) -> String? {
        let apiCacheTable = Table("api_cache")

        let idColumn = Expression<Int>("id")
        let apiTypeColumn = Expression<String>("apiType")
        let limitColumn = Expression<Int>("listLimit")
        let offsetColumn = Expression<Int>("listOffset")
        let jsonColumn = Expression<String>("jsonResponse")
        let apiVersionColumn = Expression<Int>("apiVersion")

        let query = apiCacheTable
                        .filter(idColumn == id)
                        .filter(apiTypeColumn == type.rawValue)
                        .filter(limitColumn == limit)
                        .filter(offsetColumn == offset)
                        .filter(apiVersionColumn == API_VERSION)
                        .limit(1)
        
        let row = db.pluck(query)
        let result = row?.get(jsonColumn)

        return result
    }
    
    public func getLastUsedOffsetLimit(type: APIType) -> (offset: Int?, limit: Int?) {
        let apiCacheTable = Table("api_cache")
        
        let idColumn = Expression<Int>("id")
        let apiTypeColumn = Expression<String>("apiType")
        let limitColumn = Expression<Int>("listLimit")
        let offsetColumn = Expression<Int>("listOffset")
        let apiVersionColumn = Expression<Int>("apiVersion")
        
        // NOTE(dkg): Does this return the right offset and limit at all times? Better double check this logic again!
        let query = apiCacheTable
            .filter(idColumn == API_LIST_REQUEST_ID)
            .filter(apiTypeColumn == type.rawValue)
            .filter(apiVersionColumn == API_VERSION)
            .limit(1)
        
        if let max = db.scalar(query.select(offsetColumn.max)) {
            let innerQuery = query.filter(offsetColumn == max)
            if let row = db.pluck(innerQuery) {
                let limit = row.get(limitColumn)
                return (max, limit == 0 ? nil : limit)
            } else {
                return (max, nil)
            }
        }
        
        return (nil, nil)
    }

    public func getLastUsedID(type: APIType) -> Int? {
        let apiCacheTable = Table("api_cache")
        
        let idColumn = Expression<Int>("id")
        let apiTypeColumn = Expression<String>("apiType")
        let apiVersionColumn = Expression<Int>("apiVersion")
        
        let query = apiCacheTable
            .filter(apiTypeColumn == type.rawValue)
            .filter(apiVersionColumn == API_VERSION)
            .limit(1)
        
        let max = db.scalar(query.select(idColumn.max))
        return max
    }

    public func getPokemonCount() -> Int {
        let count = db.scalar("SELECT COUNT(*) FROM pokemon") as! Int64
        return Int(count)
    }

    func getMaximumCountPokemonsAvailableFromAPI() -> Int? {
        var maxCount: Int? = nil
        
        let apiCacheTable = Table("api_cache")
        
        let idColumn = Expression<Int>("id")
        let apiTypeColumn = Expression<String>("apiType")
        let jsonColumn = Expression<String>("jsonResponse")
        let apiVersionColumn = Expression<Int>("apiVersion")
        let lastUpdatedColumn = Expression<NSDate>("lastUpdated")
        
        // TODO(dkg): we should probably look at the LAST API result that we got for the 
        //            pokemon list, instead of just a "random" (or rather the first) one like this
        
        let query = apiCacheTable
            .filter(idColumn == API_LIST_REQUEST_ID)
            .filter(apiTypeColumn == APIType.ListPokemon.rawValue)
            .filter(apiVersionColumn == API_VERSION)
            .order(lastUpdatedColumn.desc)
            .limit(1)
        
        let row = db.pluck(query)
        
        if let json = row?.get(jsonColumn) {
            let resourceList = Transformer().jsonToNamedAPIResourceList(json)
            if let list = resourceList {
                maxCount = list.count
            }
        }
        
        return maxCount
    }

    // TODO(dkg): refactor common table creation/statement execution code
    private func createCacheTable() {
        do {
            // a table to cache ALL RESTful API calls; not the best solution, but the quickest to implement
            // one could use a cache table for each individual API endpoint instead, but that's obviously more work
            let sql = "CREATE TABLE IF NOT EXISTS api_cache (" +
                      "id INTEGER NOT NULL, " + // the actual resource ID used in the request, so this is not unique on its own
                      "apiType TEXT NOT NULL, " + // the RESTful API resource that was requested
                      "listLimit INTEGER NOT NULL DEFAULT 0, " +   // limit is a reserved keyword
                      "listOffset INTEGER NOT NULL DEFAULT 0, " +  // offset might be reserved keyword
                      "apiVersion INTEGER NOT NULL DEFAULT 2, " +  // can't use the API_VERSION constant here, because the compiler complains about complexity of the expression ... what?! Why?! Must be a compiler bug.... == // Expression was too complex to be solved in reasonable time; consider breaking up the expression into distinct sub-expressions.
                      "appVersion INTEGER NOT NULL DEFAULT 1, " +  // same here
                      "lastUpdated DATETIME NOT NULL DEFAULT NOW, " +
                      "jsonResponse TEXT, " +
                      "PRIMARY KEY (apiType, id, listLimit, listOffset)" + // TODO(dkg): Should apiVersion be part of the PK?
                      ")"
//            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            logWarn("ERROR: Could not run SQL statement: \(error)")
        }
    }
    
    private func createPokemonTables() {
        do {
            // TODO(dkg): Put all information that we want to display in the UITableView cells right here
            //            in additional columns, so we do not have to parse any JSON whatsoever when we
            //            just want to display the list of pokemons - this will solve our performance issue
            //            in the ListViewController where we currently parse JSON in order to populate our
            //            PokemonTableCells!!!!
            let sql = "CREATE TABLE IF NOT EXISTS pokemon (" +
                      "id INTEGER PRIMARY KEY NOT NULL, " + // the actual resource ID for the pokemon
                      "name TEXT NOT NULL, " +
                      "favorite TINYINT NOT NULL DEFAULT 0, " +
                      "stars TINYINT NOT NULL DEFAULT 0, " +
                      "comment TEXT " +
                      ")"
//            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            log("ERROR: Could not run SQL statement: \(error)")
        }
        do {
            let sql = "CREATE TABLE IF NOT EXISTS backpack (" +
                      "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                      "pokemon_id INTEGER NOT NULL, " +
                      "foundlat FLOAT DEFAULT 0, " +
                      "foundlong FLOAT DEFAULT 0, " +
                      "founddate DATETIME DEFAULT NOW, " +
                      "name TEXT, " + // user can rename the pokemon
                      "FOREIGN KEY(pokemon_id) REFERENCES pokemon(id)" +
                      ")"
//            log("sql: \(sql)")
            let stmt = try db.prepare(sql)
            try stmt.run()
        } catch {
            logWarn("ERROR: Could not run SQL statement: \(error)")
        }
    }
    
    public func savePokemon(pokemon: Pokemon, name: String? = nil, favorite: Bool = false, stars: Int = 0, comment: String? = nil) {
        let pokemonTable = Table("pokemon")
        let idColumn = Expression<Int>("id")
        let nameColumn = Expression<String>("name")
        let favoriteColumn = Expression<Bool>("favorite")
        let starsColumn = Expression<Int>("stars")
        let commentColumn = Expression<String>("comment")
        
        let query = pokemonTable
            .filter(idColumn == pokemon.id)
            .limit(1)
        
        let newName = name == nil ? pokemon.name : name!
        let newComment = comment == nil ? "" : comment!
        
        if db.pluck(query) != nil {
            // update
            let update = query.update(nameColumn <- newName,
                                      favoriteColumn <- favorite,
                                      starsColumn <- stars,
                                      commentColumn <- newComment)
            do {
                let updatedCount = try db.run(update)
                log("updated pokemon \(pokemon.id) data: \(updatedCount)")
            } catch {
                logWarn("could not update pokemon \(pokemon.id) data: \(error)")
            }
        } else {
            // insert
            let insert = pokemonTable.insert(idColumn <- pokemon.id,
                                             nameColumn <- newName,
                                             favoriteColumn <- favorite,
                                             starsColumn <- stars,
                                             commentColumn <- newComment)
            do {
                let rowid = try db.run(insert)
                log("inserted pokemon \(pokemon.id) data: \(rowid)")
            } catch {
                logWarn("could not insert pokemon \(pokemon.id) data: \(error)")
            }
        }
    }
    
    public func getPokemonJSON(pokemonId: Int) -> String? {
        return getCachedResponse(.Pokemon, id: pokemonId)
    }

    public func updatePokemonFavoriteStatus(pokemonId: Int, isFavorite: Bool) {

        let pokemonTable = Table("pokemon")
        let idColumn = Expression<Int>("id")
        let favoriteColumn = Expression<Bool>("favorite")
        
        let query = pokemonTable
            .filter(idColumn == pokemonId)
            .limit(1)

        if db.pluck(query) != nil {
            // update
            let update = query.update(favoriteColumn <- isFavorite)
            do {
                let updatedCount = try db.run(update)
                log("updated pokemon \(pokemonId) data: \(updatedCount)")
            } catch {
                logWarn("could not update pokemon \(pokemonId) data: \(error)")
            }
        }
    }
    public func isPokemonFavorite(pokemonId: Int) -> Bool {
        let pokemonTable = Table("pokemon")
        let idColumn = Expression<Int>("id")
        let favoriteColumn = Expression<Bool>("favorite")
        
        let query = pokemonTable.select(favoriteColumn)
                                .filter(idColumn == pokemonId)
        let row = db.pluck(query)
        
        return (row?.get(favoriteColumn))!
    }

//    public func loadPokemons() -> [Pokemon] {
    public func loadPokemons(limit: Int = 0) -> [String] {
        log("loadPokemons() start")
        let pokemonTable = Table("pokemon")
        let apiCacheTable = Table("api_cache")
        let nameColumn = Expression<String>("name")
        let pokemonIdColumn = Expression<Int>("id")
        let idColumn = Expression<Int>("id")
        let jsonColumn = Expression<String>("jsonResponse")
        let apiTypeColumn = Expression<String>("apiType")
        
        let joinQuery = pokemonTable.join(apiCacheTable, on: apiCacheTable[idColumn] == pokemonTable[pokemonIdColumn])
                                    .filter(apiTypeColumn == APIType.Pokemon.rawValue)
                                    .order(nameColumn)
        let query = joinQuery.select(jsonColumn).order(nameColumn)
//        let query = joinQuery.select(pokemonTable[pokemonIdColumn]).order(nameColumn)
        
        var rows: AnySequence<Row>? = nil
        if limit > 0 {
            rows = try! db.prepare(query.limit(limit))
        } else {
            rows = try! db.prepare(query)
        }
        
        // NOTE(dkg): Using the JSONDecoder like this in the loop is really, really slow.
        //            Especially if we have more than a few Pokemons in the list.
        
//        var result = [Pokemon]() ==> SLOWEST OF ALL!
//        var result = [Int]() ==> Fastest of all, however then the actual cell drawing/rendering takes longer because
//                                 each cell has to query the db again for the json and then parse it to a Pokemon object.
        var result = [String]() // middle ground: no need for individual JSON lookup, but needs extra parsing for each cell
                                // when drawing
        for row in rows! {
            // NOTE(dkg): this autoreleasepool has a performance impact, but it also solve the memory pressure
            //            will need further profiling to figure out what the best course of action would be
            autoreleasepool({
            
                let json = row.get(jsonColumn)
//                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
//                let pokemon = try! Pokemon(JSONDecoder(data))
                
//                let id: Int = row.get(pokemonTable[pokemonIdColumn])

                // TODO(dkg): Actually replace the name with the custom name the user may have given this pokemon?!
                //            That is, if we ever figure out how we want this feature to work.
                //            Or remove this incomplete feature again.

//                result.append(pokemon)
                result.append(json)
                
            })
        }
        
        log("loadPokemons() end")
        
        return result
    }
    
    public func loadFavoritePokemons() -> [Pokemon] {
        log("loadFavoritePokemons() start")

        let pokemonTable = Table("pokemon")
        let apiCacheTable = Table("api_cache")
        let nameColumn = Expression<String>("name")
        let pokemonIdColumn = Expression<Int>("id")
        let idColumn = Expression<Int>("id")
        let favoriteColumn = Expression<Bool>("favorite")
        let jsonColumn = Expression<String>("jsonResponse")
        let apiTypeColumn = Expression<String>("apiType")
        
        let joinQuery = pokemonTable.join(apiCacheTable, on: apiCacheTable[idColumn] == pokemonTable[pokemonIdColumn])
                                    .filter(apiTypeColumn == APIType.Pokemon.rawValue)
                                    .filter(favoriteColumn == true)
                                    .order(nameColumn)
        let query = joinQuery.select(jsonColumn)
        
        let rows = try! db.prepare(query)
        let transformer = Transformer()

        var result = [Pokemon]()
        for row in rows {
            autoreleasepool({
                
                let json = row.get(jsonColumn)
                if let pokemon = transformer.jsonToPokemonModel(json) {
                    result.append(pokemon)
                }
            })
        }
        
        log("loadFavoritePokemons() end")
        
        return result
    }
    
    
    public func savePokemonInBackpack(pokemon: Pokemon, latitude: Double, longitude: Double, name: String? = nil) {
        let backpackTable = Table("backpack")
        let pokemonColumn = Expression<Int>("pokemon_id")
        let latColumn = Expression<Double>("foundlat")
        let longColumn = Expression<Double>("foundlong")
        let dateColumn = Expression<NSDate>("founddate")
        let nameColumn = Expression<String>("name")
        
        let newName = name == nil ? pokemon.name : name!
        
        // always insert - we can have several pokemons of the same type/name in the backpack
        let insert = backpackTable.insert(pokemonColumn <- pokemon.id,
                                          nameColumn <- newName,
                                          latColumn <- latitude,
                                          longColumn <- longitude,
                                          dateColumn <- NSDate())
        do {
            let rowid = try db.run(insert)
            log("inserted pokemon \(pokemon.id) data in backpack: \(rowid)")
        } catch {
            logWarn("could not insert pokemon \(pokemon.id) data in backpack: \(error)")
        }
    }
    
    public func removePokemonFromBackpack(pokemon: Pokemon, caughtOnDate: NSDate) {
        let backpackTable = Table("backpack")
        let pokemonColumn = Expression<Int>("pokemon_id")
        let dateColumn = Expression<NSDate>("founddate")
        let pokemonRow = backpackTable.filter(pokemonColumn == pokemon.id)
                                      .filter(dateColumn == caughtOnDate)
        do {
            let rowid = try db.run(pokemonRow.delete())
            log("delete pokemon \(pokemon.id) data from backpack: \(rowid)")
        } catch {
            logWarn("could not delete pokemon \(pokemon.id) data from backpack: \(error)")
        }
    }
    
    public func loadPokemonFromBackpack(pokemonId: Int) -> Pokemon? {
        let backpackTable = Table("backpack")
        let pokemonIdColumn = Expression<Int>("pokemon_id")
        let apiCacheTable = Table("api_cache")
        let apiTypeColumn = Expression<String>("apiType")
        let idColumn = Expression<Int>("id")
        let jsonColumn = Expression<String>("jsonResponse")
        
        let joinQuery = backpackTable.join(apiCacheTable, on: apiCacheTable[idColumn] == backpackTable[pokemonIdColumn])
                                     .filter(apiTypeColumn == APIType.Pokemon.rawValue)
                                     .filter(backpackTable[pokemonIdColumn] == pokemonId)
        let query = joinQuery.select(jsonColumn)
        
        if let row = db.pluck(query) {
            return Transformer().jsonToPokemonModel(row.get(jsonColumn))
        } else {
            return nil
        }
    }
    
    // TODO(dkg): this is slow when there are a lot of pokemon in the backpack - find a more
    //            performant way to do this
    public func loadPokemonsFromBackpackAsPokemonAnnotations() -> [PokemonAnnotation] {
        log("loadPokemonsFromBackpack() start")

        let backpackTable = Table("backpack")
        let apiCacheTable = Table("api_cache")
        let nameColumn = Expression<String>("name")
        let pokemonIdColumn = Expression<Int>("pokemon_id")
        let idColumn = Expression<Int>("id")
        let jsonColumn = Expression<String>("jsonResponse")
        let apiTypeColumn = Expression<String>("apiType")
        let latColumn = Expression<Double>("foundlat")
        let longColumn = Expression<Double>("foundlong")
        let dateColumn = Expression<NSDate>("founddate")
        
        let joinQuery = backpackTable.join(apiCacheTable, on: apiCacheTable[idColumn] == backpackTable[pokemonIdColumn])
                                     .filter(apiTypeColumn == APIType.Pokemon.rawValue)
                                     .order(nameColumn)
        let query = joinQuery.select(jsonColumn, latColumn, longColumn, dateColumn)
        
        let rows = try! db.prepare(query)
        let transformer = Transformer()
        let dl = Downloader()
        
        var result = [PokemonAnnotation]()
        for row in rows {
            autoreleasepool({
                
                let json = row.get(jsonColumn)
                if let pokemon = transformer.jsonToPokemonModel(json) {
                    let lat = row.get(latColumn)
                    let lon = row.get(longColumn)
                    let coords: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let image = dl.getPokemonSpriteFromCache(pokemon)
                    let date = row.get(dateColumn)
                    let annotation = PokemonAnnotation(coordinate: coords, pokemon: pokemon, image: image, found: date)

                    result.append(annotation)
                }
            })
        }
        
        log("loadPokemonsFromBackpack() end")
        
        return result
        
    }
    
}

