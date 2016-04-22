//
//  Downloader.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import Alamofire
import JSONJoy
//import BrightFutures // TODO(dkg): if not used, remove from Podfile as well!!!!!

private let API_BASE_URL = "http://pokeapi.co/api/v2"
private let API_POKEMON_URL = API_BASE_URL + "/pokemon"


// TODO(dkg): figure out how to "include" the actual resource name for each error case - maybe custom constructor or
//            some meta-programming magic?
public enum APIError: String {
    case NoError = "OK"
    case APINoJSONResponse = "API returned no JSON."
    case APILimitReached = "API limit was reached for this resource."
    case APIResponseTimeout = "The API did not return a response in time."
    case API404 = "The API could not find the requested resource."
    case APIOther = "The API returned an unknwon error."
    case APIJSONTransformationFailed = "The JSON response could not be transformed into an object."
    case APICouldNotSaveToCacheOrFile = "Could not save the API response to the cache or a file."
    case APINoSpriteForThisType = "No sprite for this type."
}

public enum PokemonSpriteType: String {
    case FrontDefault, FrontShiny, FrontFemale, FrontShinyFemale
    case BackDefault, BackShiny, BackFemale, BackShinyFemale
}

// NOTE(dkg): - This class should be unaware about threads - the caller should handle this
//            - Also note that Alamofire is async(!!!) - therefore this class is as well
//            - The downloader class saves all downloaded data to the cache db (or as files in case of binary data)
public class Downloader: NSObject {

    private let manager: Manager
    
    public override init() {
        manager = Alamofire.Manager.sharedInstance
        // TODO(dkg): maybe this setting would be nice to have in the UI in a settings view controller
        manager.session.configuration.timeoutIntervalForRequest = 15.0 // 15.0 seconds timeout

        super.init()
    }
    
    public func startDownload(type: APIType, offset: Int = 0, limit: Int = 20, id: Int = API_LIST_REQUEST_ID, completed: (json: String?, error: APIError) -> Void) {
        log("download start")

        var url: String? = nil;
        switch(type) {
        case .ListPokemon:
            url = "\(API_POKEMON_URL)/?limit=\(limit)&offset=\(offset)"
            break
        case .Pokemon:
            url = "\(API_POKEMON_URL)/\(id)/"
        default:
            assertionFailure("TODO! Implement this case \(type)")
            break
        }
        
        if let requestUrl = url {
            startDownload(requestUrl, completed: completed)
        } else {
            assertionFailure("WARNING: url not set for download!")
        }
    }

    public func startDownload(url: String, completed: (json: String?, error: APIError) -> Void) {
        log("startDowloadList request: \(url)")
        let request = manager.request(NSURLRequest(URL: NSURL(string: url)!))
        request.responseString { response in
            log("Request is success: \(response.result.isSuccess)")
            if response.result.isSuccess {
                completed(json: response.result.value, error: .NoError)
            } else {
                completed(json: nil, error: .APIOther) // TODO(dkg): Figure out the real error here and pass it on accordingly.
            }
        }
    }
    
    public func startDownloadPokemonList(offset: Int = 0, limit: Int = 20, completed: (resourceList: NamedAPIResourceList?, error: APIError) -> Void) {
        log("startDownloadPokemons(\(offset), \(limit))")

        startDownload(.ListPokemon, offset: offset, limit: limit, completed: { json, error in
//            log("download done!!!! \(json)")
            log("one download done")
            
            if let dataString = json {
                // This json is a list of links for the actual Pokemon endpoint that gives us the individual
                // Pokemon data. We need to manually download each of those.

                let db = DB()
                db.insertOrUpdateCachedResponse(APIType.ListPokemon, json: dataString, offset: offset, limit: limit)

                let resourceList = Transformer().jsonToNamedAPIResourceList(dataString)
                if let list = resourceList {
                    completed(resourceList: list, error: .NoError)
//                    // TODO(dkg): would need Futures/Promises here for this
//                    for resource in resourceList.results {
//                        downloadPokemon(resource.url)
//                    }
                } else {
                    logWarn("Could not convert JSON to NamedAPIResourceList.")
                    completed(resourceList: nil, error: .APIJSONTransformationFailed)
                }
                
            } else {
                logWarn("Could not get data from request - no valid response")
                completed(resourceList: nil, error: .APINoJSONResponse)
            }
            
        })
    }
    
    public func downloadPokemon(id: Int, completed: (pokemon: Pokemon?, error: APIError) -> Void) {
        startDownload(APIType.Pokemon, id: id, completed: { json, error in
            self.cachePokemonAndTransform(json, error: error, completed: completed)
        })
    }
    
    public func downloadPokemon(url: String, completed: (pokemon: Pokemon?, error: APIError) -> Void) {
        startDownload(url, completed: { json, error in
            self.cachePokemonAndTransform(json, error: error, completed: completed)
        })
    }
    
    private func cachePokemonAndTransform(json: String?, error: APIError, completed: (pokemon: Pokemon?, error: APIError) -> Void) {
        if let dataString = json {
            
            log("downloaded pokemon json")
            let data: NSData = dataString.dataUsingEncoding(NSUTF8StringEncoding)!
            
            let db = DB()
            let id = extractIdFromJson(dataString)

            db.insertOrUpdateCachedResponse(APIType.Pokemon, json: dataString, id: id)
            
            do {
                let pokemon = try Pokemon(JSONDecoder(data))
                
                // also save the pokemon in our special pokemon table
                db.savePokemon(pokemon)
                
                completed(pokemon: pokemon, error: .NoError)
            } catch {
                logWarn("Could not convert Pokemon JSON to Pokemon object. \(error)")
                completed(pokemon: nil, error: .APIJSONTransformationFailed)
            }
            
        } else {
            logWarn("Could not get data from request - no valid response")
            completed(pokemon: nil, error: .APINoJSONResponse)
        }
    }
    
    // TODO(dkg): Move this into Utils.swift?
    public func extractIdFromJson(json: String) -> Int {
        
        let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!

        do {
            let apiId = try APIID(JSONDecoder(data))
            return apiId.id
        } catch {
            // TODO(dkg): fallbacks -  actually not needed any longer, should be removed
            let pattern: String = "\"id\":(\\d),"
            let id = extractIdFromText(json, pattern: pattern)
            
            if id != 0 {
                return id
            }
            
            var range = json.rangeOfString(",")!
            var text = json.substringToIndex(range.endIndex.advancedBy(-1))
            
            range = text.rangeOfString(":")!
            text = text.substringFromIndex(range.startIndex.advancedBy(1))
            
            let oid = Int(text)
            
            if let idi = oid {
                return idi
            }
        }
        
        logWarn("Could not find id in json!")
        logWarn(json)
        
        return 0
    }
    
    // TODO(dkg): Move this into Utils.swift?
    public func extractIdFromUrl(url: String) -> Int {
        // "http://pokeapi.co/api/v2/pokemon/3/ ==> return 3
//        log("url from id \(url)")
        let pattern: String = "(\\d*)\\/$"
        return extractIdFromText(url, pattern: pattern)
    }
    
    // TODO(dkg): Move this into Utils.swift?
    private func extractIdFromText(text: String, pattern: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = text as NSString
            let results = regex.matchesInString(text,
                                                options: [], range: NSMakeRange(0, nsString.length))
            if results.count > 0 {
                let firstMatch = results[0]
                let possibleId = nsString.substringWithRange(firstMatch.rangeAtIndex(1))
                return Int(possibleId)!
            }
            return 0
        } catch let error as NSError {
            logWarn("could not find or convert id from text: \(error.localizedDescription)")
            return 0
        }
    }
    
    public func getPokemonSpriteFromCache(pokemonJson: String, type: PokemonSpriteType = .FrontDefault) -> UIImage? {
        // TODO(dkg): add autoreleasepool here?
        if let pokemon = Transformer().jsonToPokemonModel(pokemonJson) {
            return getPokemonSpriteFromCache(pokemon)
        } else {
            return nil
        }
    }
    
    public func getPokemonSpriteFromCache(pokemonId: Int, type: PokemonSpriteType = .FrontDefault) -> UIImage? {
        // TODO(dkg): add autoreleasepool here?
        if let pokemon = Transformer().jsonToPokemonModel(DB().getPokemonJSON(pokemonId)) {
            return getPokemonSpriteFromCache(pokemon)
        } else {
            return nil
        }
    }

    public func getPokemonSpriteFromCache(pokemon: Pokemon, type: PokemonSpriteType = .FrontDefault) -> UIImage? {
        // "sprites":{"back_female":null,"back_shiny_female":null,"back_default":"http://pokeapi.co/media/sprites/pokemon/back/2.png", ...
        
        if let fileName = createPokemonSpriteFilename(pokemon, type: type) {
            if fileExists(fileName) {
//                log("filename exists: \(fileName)")
                return UIImage(contentsOfFile: fileName)
            } else {
                log("filename does not exists: \(fileName)")
            }
        } else {
            log("no sprite \(type) for pokemon \(pokemon.name)")
        }

        return nil
    }
    
    // TODO(dkg): improve error handling
    
    public func downloadPokemonSprite(pokemonJson: String, type: PokemonSpriteType = .FrontDefault, completed: (error: APIError) -> Void) {
        // TODO(dkg): add autoreleasepool here?
        if let pokemon = Transformer().jsonToPokemonModel(pokemonJson) {
            downloadPokemonSprite(pokemon, type: type, completed: completed)
        } else {
            log("could not load or convert Pokemon for JSON data")
            completed(error: APIError.APIJSONTransformationFailed)
        }
    }
    
    public func downloadPokemonSprite(pokemonId: Int, type: PokemonSpriteType = .FrontDefault, completed: (error: APIError) -> Void) {
        // TODO(dkg): add autoreleasepool here?
        if let pokemon = Transformer().jsonToPokemonModel(DB().getPokemonJSON(pokemonId)) {
            downloadPokemonSprite(pokemon, type: type, completed: completed)
        } else {
            log("could not load or convert Pokemon for ID \(pokemonId)")
            completed(error: APIError.APIJSONTransformationFailed)
        }
    }

    public func downloadPokemonSprite(pokemon: Pokemon, type: PokemonSpriteType = .FrontDefault, completed: (error: APIError) -> Void) {
        if let fileName = createPokemonSpriteFilename(pokemon, type: type) {
            if let url = getPokemonSpriteUrl(pokemon, type: type) {
                Alamofire.request(.GET, url)
                    .responseData { response in
                        log("Request is success: \(response.result.isSuccess)")
                        if response.result.isSuccess {
                            if let data: NSData = response.result.value {
                                if data.writeToFile(fileName, atomically: true) {
                                    log("wrote file : \(fileName)")
                                    completed(error: .NoError)
                                } else {
                                    completed(error: .APICouldNotSaveToCacheOrFile)
                                }
                                return
                            }
                        }
                        completed(error: .APIOther) // TODO(dkg): Figure out the real error here and pass it on accordingly.
                }
            } else {
                log("could not get url for sprite download")
                completed(error: APIError.APIOther)
            }
        } else {
//            log("could not create filename for sprite download")
            completed(error: APIError.APINoSpriteForThisType)
        }
    }
    
    private func getPokemonSpriteUrl(pokemon: Pokemon, type: PokemonSpriteType = .FrontDefault) -> String? {
        var spriteUrl: String? = nil
        
        switch (type) {
        case .BackFemale:
            spriteUrl = pokemon.sprites.back_female
            break
        case .BackShinyFemale:
            spriteUrl = pokemon.sprites.back_shiny_female
            break
        case .BackDefault:
            spriteUrl = pokemon.sprites.back_default
            break
        case .BackShiny:
            spriteUrl = pokemon.sprites.back_shiny
            break
        case .FrontFemale:
            spriteUrl = pokemon.sprites.front_female
            break
        case .FrontShinyFemale:
            spriteUrl = pokemon.sprites.front_shiny_female
            break
        case .FrontDefault:
            spriteUrl = pokemon.sprites.front_default
            break
        case .FrontShiny:
            spriteUrl = pokemon.sprites.front_shiny
            break
        default:
            assertionFailure("unknown enum value for PokemonSpriteType! \(type)")
        }

        return spriteUrl
    }
    
    // need to somehow figure out a unique filename per pokemon per sprite type
    private func createPokemonSpriteFilename(pokemon: Pokemon, type: PokemonSpriteType = .FrontDefault) -> String? {
        // "sprites": { "back_default":"http://pokeapi.co/media/sprites/pokemon/back/2.png", ...}
        
        if let url = getPokemonSpriteUrl(pokemon, type: type) {
            if let range = url.rangeOfString("://") {
                let folder = applicationDocumentsFolder() as NSString
                let urlFile = url.substringFromIndex(range.endIndex) as NSString
                let path = folder.stringByAppendingPathComponent(urlFile.stringByDeletingLastPathComponent) as NSString
                let name = urlFile.lastPathComponent
                
//                log("path name \(path) \(name)")
                
                if createFolderIfNotExists(path as String) {
                    let fileName = path.stringByAppendingPathComponent(name)
                    return fileName
                }
            }
        }
        return nil
    }
    

}
