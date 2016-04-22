//
//  Transformer.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import JSONJoy

// TODO(dkg): Does this have to be a class? Could those functions be static functions on the class? Or
//            even standalone functions?
//
// TODO(dkg): The methods have a lot of code in common - maybe refactor?
//
public class Transformer {

    public func jsonToPokemonModel(json: String?) -> Pokemon? {
        var pokemon: Pokemon? = nil
        
        if let json = json {
            autoreleasepool({
                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
                do {
                    pokemon = try Pokemon(JSONDecoder(data))
                } catch {
                    logWarn("Could not convert JSON to Pokemon. \(error)")
                    pokemon = nil
                }
            })
        }

        return pokemon
    }

    public func jsonToNamedAPIResourceList(json: String?) -> NamedAPIResourceList? {
        var resourceList: NamedAPIResourceList? = nil
        
        if let json = json {
            autoreleasepool({
                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
                do {
                    resourceList = try NamedAPIResourceList(JSONDecoder(data))
                } catch {
                    logWarn("Could not convert JSON to NamedAPIResourceList. \(error)")
                    resourceList = nil
                }
            })
        }

        return resourceList
    }

    public func jsonToPokemonSpecies(json: String?) -> PokemonSpecies? {
        var pokemonSpecies: PokemonSpecies? = nil
        
        if let json = json {
            autoreleasepool({
                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
                do {
                    pokemonSpecies = try PokemonSpecies(JSONDecoder(data))
                } catch {
                    logWarn("Could not convert JSON to PokemonSpecies. \(error)")
                    pokemonSpecies = nil
                }
            })
        }
        
        return pokemonSpecies
    }

    public func jsonToMove(json: String?) -> Move? {
        var move: Move? = nil
        
        if let json = json {
            autoreleasepool({
                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
                do {
                    move = try Move(JSONDecoder(data))
                } catch {
                    logWarn("Could not convert JSON to Move. \(error)")
                    move = nil
                }
            })
        }

        return move
    }
    
    public func jsonToPokemonForm(json: String?) -> PokemonForm? {
        var form: PokemonForm? = nil
        
        if let json = json {
            autoreleasepool({
                let data: NSData = json.dataUsingEncoding(NSUTF8StringEncoding)!
                do {
                    form = try PokemonForm(JSONDecoder(data))
                } catch {
                    logWarn("Could not convert JSON to PokemonForm. \(error)")
                    form = nil
                }
            })
        }
        
        return form
    }
}