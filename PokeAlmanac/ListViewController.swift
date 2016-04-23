//
//  ListViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit
import ReachabilitySwift

private let LOAD_NEXT_MAX_ITEMS: Int = 10
private let CELL_IDENTIFIER: String = "pokemonTableCellIdentifier"
private let CELL_IDENTIFIER_LOAD_MORE: String = "pokemonTableLoadMoreCell"


// TODO(dkg): lots of duplicated code between this and the FavoritesViewController - think about
//            better BaseListViewController class implementation for common code
// TODO(dkg): add search bar to filter list
// TODO(dkg): add a ProgressView when ever downloading either JSON or Images
// TODO(dkg): need a way to invalidate the response cache

class ListViewController: UITableViewController {
    
    let dl = Downloader()
    let db = DB()
    let transformer = Transformer()
    
//    var data: [Pokemon]? = nil
//    var data: [Int]? = nil
    var data: [String]? = nil
    var busyIndicator: BusyOverlay? = nil
    
    var requestedMoreData: Bool = false
    var downloadingSpritesInBackground: Bool = false
    var downloadingSpritesAlready: Bool = false
    var downloadingAlready: Bool = false

    // API endpoint parameters
    var currentOffset: Int = 0
    var currentLimit: Int = LOAD_NEXT_MAX_ITEMS
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("ListViewController")
        
        
        let count = self.db.getPokemonCount()
        self.title = "\(count) Pokemons"
        
        busyIndicator = BusyOverlay()
     
        // Load data from cache, and if we don't have any, request it from the server
        loadData()
    }
 
    func loadData() {
        log("loadData")

        let reachability: Reachability
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
            let current: Reachability.NetworkStatus = reachability.currentReachabilityStatus
            log("current \(current) reachability")
            
            if current == Reachability.NetworkStatus.NotReachable {
                showErrorAlert(self, message: "Please make sure you have an online connection either through WiFi or 3G/4G.", title: "No connectivity!", completion: {
                    // try again in 15 seconds
                    self.performSelector(#selector(self.loadData), withObject: nil, afterDelay: 15.0)
                })
                return
            }
        } catch {
            logWarn("Unable to create Reachability: \(error)")
        }
        
        // TODO(dkg): only load the first 20 or so Pokemon, even from DB, and then load more as we go
        //            data = db.loadPokemons(currentLimit)
        //            it is not this easy ... need to rethink caching architecture and loading here
        data = db.loadPokemons()
        let count = data == nil ? 0 : data!.count

        if count > 0 {
            log("we have data \(count)")
            // TODO(dkg): figure out what we need to set the currentOffset and currentLimit to!
            self.tableView.reloadData()
            
            // make sure we also load the thumbnails in case some are missing
            self.downloadSpritesInBackground()
            
        } else {
            
            // check cache first to see if we have the data already
            let cachedResponse = db.getCachedResponse(APIType.ListPokemon, offset: currentOffset, limit: currentLimit)
            if let response = cachedResponse {
                busyIndicator?.showOverlay()

                let resourceList = self.transformer.jsonToNamedAPIResourceList(response)
                
                loadDataFromResourceList(resourceList)

            } else {
                busyIndicator?.showOverlay()
                downloadMoreDataInBackground()
            }
        }
    }
    
    //
    // NOTE(dkg):
    // The more Pokemon in the cache, the longer it takes to download additional pokemons.
    // The JSON parsing for the UITableView data takes quite a time when done in a loop for all Pokemons.
    // Possible solution could be to only parse data when the tableView requests a cell for display, 
    // and not parse it upfront for all pokemons in the list! That should speed up things for longer
    // lists (60+ pokemon).
    //
    func downloadMoreDataInBackground() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            
            // check cache first to see if we have the data already
            let cachedResponse = self.db.getCachedResponse(APIType.ListPokemon, offset: self.currentOffset, limit: self.currentLimit)
            if let response = cachedResponse {
                self.busyIndicator?.showOverlay()
                
                let resourceList = self.transformer.jsonToNamedAPIResourceList(response)
                
                self.loadDataFromResourceList(resourceList)
                
            } else {
                
                if self.downloadingAlready {
                    return
                }
                self.downloadingAlready = true
                
                self.dl.startDownloadPokemonList(self.currentOffset, limit: self.currentLimit, completed: { resourceList, error in
                    log("done saving list - get individual pokemons now")
                    self.downloadingAlready = false
                    if error == APIError.NoError {
                        self.loadDataFromResourceList(resourceList)
                    } else {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.busyIndicator?.hideOverlayView()
                            showErrorAlert(self, message: "Some Pokemon data could not be downloaded.\nReason: \(error.rawValue)", title: "Download Error")
                            if self.requestedMoreData {
                                self.requestedMoreData = false
                                self.reloadTableData()
                            }
                        })
                    }
                })
            }
        });
    }
    
    func loadDataFromResourceList(resourceList: NamedAPIResourceList?) {
        
        let count = self.currentLimit // poor man's future.all/promise.all "solution"
        var counter = 0
        var errors = 0
        
        func done(errors: Int) {
            log("done with all pokemon downloads")
            dispatch_async(dispatch_get_main_queue(), {
                self.requestedMoreData = false
                self.downloadingAlready = false
                
                self.reloadTableData()
                self.busyIndicator?.hideOverlayView()
                
                self.downloadSpritesInBackground()
                
                if errors > 0 {
                    showErrorAlert(self, message: "Some Pokemon data could not be downloaded.", title: "Download Error")
                }
            })
        }
        
        if let list = resourceList {
            
            // TODO(dkg): Should this be refactored so the individual download happens in the Downloader
            //            right after the list was downloaded?
            let results = list.results

            for resource in results {
                
                autoreleasepool({
                    // TODO(dkg): think about how to force to re-download data - maybe invalidate the cache after a time?
                    let url = resource.url
                    let id = dl.extractIdFromUrl(url)
                    let cachedResponse = id != 0 ? db.getCachedResponse(APIType.Pokemon, id: id) : nil
                    
                    log("resource : \(id) - \(resource)")

                    if let response = cachedResponse {
                        log("already downloaded data for this id \(id)")
                        counter += 1
                        
                        let temp = self.transformer.jsonToPokemonModel(response)
                        log("success? \(temp != nil)")
                        
                        if (counter == count) {
                            done(errors)
                        }
                    } else {
                        log("download another pokemon from \(url)")
                        // TODO(dkg): use a queue or something in order to not fire too many downloads at once!
                        dl.downloadPokemon(url, completed: { pokemon, error in
                            log("downloaded another pokemon from \(url)")
                            counter += 1
                            
                            if error != APIError.NoError {
                                errors += 1
                            }
                            
                            if (counter == count) {
                                done(errors)
                            }
                        })
                    } // if
                }) // autoreleasepool
            } // for
        } else {
            log("Could not convert JSON to NamedAPIResourceList.")
            // TODO(dkg): report to user?
        }
    }
    
    func downloadSpritesInBackground() {
        log("downloadSpritesInBackground")
        if downloadingSpritesInBackground {
            return
        }

        downloadingSpritesInBackground = true
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { [unowned self] in
            autoreleasepool({
                self.downloadSprites()
            })
        }
        
    }
    
    func downloadSprites() {
        log("downloadSprites")
        
        if self.downloadingSpritesAlready {
            log("not downloading sprites now - already doing it")
            return
        }
        self.downloadingSpritesAlready = true
        
        let pokemonData = db.loadPokemons() // "global" data object might not be up-to-date right now
        
        let count = pokemonData.count
        var counter = 0
        var errors = 0
        
        func done(errors: Int) {
            log("done downloading sprites")
            dispatch_async(dispatch_get_main_queue(), {
                
                self.downloadingSpritesInBackground = false
                self.downloadingSpritesAlready = false
                self.reloadTableData()
                self.busyIndicator?.hideOverlayView()
                
                if errors > 0 {
                    showErrorAlert(self, message: "Could not download some Pokemon sprites.")
                }
            })
        }
        
        for pokemonJson in pokemonData {
            autoreleasepool({
//                self.busyIndicator?.showOverlay()//TODO(dkg): when we are in a background thread then this is not good!
                
                if let _ = dl.getPokemonSpriteFromCache(pokemonJson) {
                    
                    counter += 1
                    if counter == count {
                        done(errors)
                    }

                } else {
                    
                    dl.downloadPokemonSprite(pokemonJson, completed: { (sprite, error) in
                        
                        if error != APIError.NoError {
                            errors += 1
                        }
                        
                        counter += 1
                        
                        if counter == count {
                            done(errors)
                        }

                    }) // download
                } // if
            }) // autoreleasepool
        }
    }
    
    func reloadTableData() {
        autoreleasepool({
            self.data = DB().loadPokemons()
        })
        // make sure we are actually visible, otherwise don't bother
        if self.isViewLoaded() && self.view.window != nil {
            self.tableView.reloadData()
        }
    }
    
    func getMaximumCountPokemons() -> Int {
        var maxCount = -1
        
        let cachedResponse = self.db.getCachedResponse(APIType.ListPokemon, offset: 0, limit: self.currentLimit)
        if let response = cachedResponse {
            let resourceList = self.transformer.jsonToNamedAPIResourceList(response)
            if let list = resourceList {
                maxCount = list.count
            }
        }
        
        return maxCount
    }
    
    // tableView callbacks
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // check if we already reached the end?! if so, no need to load more data
        let maxCount = getMaximumCountPokemons()
        
        if let theData = self.data {
            if theData.count >= maxCount && maxCount > 0 {
                return theData.count
            } else {
                return theData.count + 1 // + 1 is for the "loading more data" cell
            }
        } else {
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    
        let count = data!.count
        
        // check if we already reached the end?! if so, no need to load more data
        let maxCount = getMaximumCountPokemons()
        
        
        if (indexPath.row == count && count < maxCount && maxCount > 0) || (count == 0 && maxCount == -1) {
            // "loading" cell
            let cell: PokemonTableLoadMoreCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER_LOAD_MORE) as! PokemonTableLoadMoreCell
            
            if !self.requestedMoreData {

                requestedMoreData = true
                
                if count > 0 {
                    currentOffset += currentLimit
                }

                self.busyIndicator?.showOverlay()
                downloadMoreDataInBackground()
            }
            
            cell.activityIndicator?.startAnimating()
            
            return cell
        } else {
        
            let cell: PokemonTableCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER, forIndexPath: indexPath) as! PokemonTableCell
            
            if indexPath.row < count {
                // TODO(dkg): this is still pretty slow, as the DB() object has to be instantiated for each cell, and then access the DB
                //            etc
                if let pokemonData = data {
                    let pokemonJson = pokemonData[indexPath.row]
                    cell.setPokemonDataJson(pokemonJson)
                } else {
                    cell.clearCell()
                }
            } else {
                log("this should not happen")
            }
            
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        log("Tapped on cell at \(indexPath)")
        
        if let pokemonData = data {
            let pokemonJson = pokemonData[indexPath.row]
            let vc: PokemonDetailViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PokemonDetailViewController") as! PokemonDetailViewController
            self.navigationController?.pushViewController(vc, animated: true, completion: { () in
                vc.setPokemonDataJson(pokemonJson)
            })
        }
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        log("editActionsForRowAtIndexPath \(indexPath)")
        // NOTE(dkg): Maybe use a 3rd party library for this instead, that allows swipes in all directions and has different
        //            animation options for the swipe, e.g. https://github.com/MortimerGoro/MGSwipeTableCell

        if let pokemonData = data {
            let pokemonJson = pokemonData[indexPath.row]
            let pokemon = self.transformer.jsonToPokemonModel(pokemonJson)!
            let isFav = db.isPokemonFavorite(pokemon.id)
            let title = isFav ? "Un-Favorite" : "Favorite"
            
            let favorite = UITableViewRowAction(style: .Normal, title: title) { action, indexPath in
                if let pokemonData = self.data {
                    let pokemonJson = pokemonData[indexPath.row]
                    let pokemon = self.transformer.jsonToPokemonModel(pokemonJson)!
                    let isFavReverse = !self.db.isPokemonFavorite(pokemon.id)
                    let title = isFavReverse ? "Un-Favorite" : "Favorite"
                    
                    self.db.updatePokemonFavoriteStatus(pokemon.id, isFavorite: isFavReverse)
                    
                    action.title = title
                    
                    self.tableView.setEditing(false, animated: true)
                }
            }
            favorite.backgroundColor = UIColor.orangeColor()
            
            return [favorite]
        } else {
            return []
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        logWarn("didReceiveMemoryWarning")
    }

}

