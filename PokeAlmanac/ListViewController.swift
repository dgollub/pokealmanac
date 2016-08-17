//
//  ListViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit
import ReachabilitySwift // TODO(dkg): remove this dependency, as Alamofire already provides the same feature!

private let LOAD_NEXT_MAX_ITEMS: Int = 10
private let CELL_IDENTIFIER: String = "pokemonTableCellIdentifier"
private let CELL_IDENTIFIER_LOAD_MORE: String = "pokemonTableLoadMoreCell"


// TODO(dkg): lots of duplicated code between this and the FavoritesViewController - think about
//            better BaseListViewController class implementation for common code
// TODO(dkg): add search bar to filter list
// TODO(dkg): add a ProgressView when ever downloading either JSON or Images
// TODO(dkg): need a way to invalidate the response cache

class ListViewController: UITableViewController, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar?

    let dl = Downloader()
    let db = DB()
    let transformer = Transformer()
    
//    var data: [Pokemon]? = nil
//    var data: [Int]? = nil
    var data: [String]? = nil
    var busyIndicator: BusyOverlay? = nil
    var maxPokemonCountAPI: Int? = nil
    
    // TODO(dkg): clean this up, this is not very nice/neat
    var requestedMoreData: Bool = false
    var downloadingSpritesInBackground: Bool = false
    var downloadingSpritesAlready: Bool = false
    var downloadingAlready: Bool = false
    
    var displaySearchResults: Bool = false

    // API endpoint parameters
    var currentOffset: Int = 0
    var currentLimit: Int = LOAD_NEXT_MAX_ITEMS
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("ListViewController")
        
//        let count = self.db.getPokemonCount()
        let count = 0
        self.title = "\(count) Pokemons"
        
        busyIndicator = BusyOverlay()
     
        displaySearchResults = false
        
        // Load data from cache, and if we don't have any, request it from the server
        loadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if searchBar?.delegate == nil {
            searchBar?.delegate = self
        }
    }
 
    func loadData() {
        log("loadData")
        
        // TODO(dkg): clean up reachability checking
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
        
//        // TODO(dkg): only load the first 20 or so Pokemon, even from DB, and then load more as we go
//        //            data = db.loadPokemons(currentLimit)
//        //            it is not this easy ... need to rethink caching architecture and loading here
//        data = db.loadPokemons()
//        let count = data == nil ? 0 : data!.count
//
//        if count > 0 {
//            log("we have data \(count)")
//            
//            maxPokemonCountAPI = db.getMaximumCountPokemonsAvailableFromAPI()
//            
//            let (offset, limit) = db.getLastUsedOffsetLimit(APIType.ListPokemon)
//            if let offset = offset {
//                currentOffset = offset
//            }
//            if let limit = limit {
//                currentLimit = limit
//            }
//
//            // TODO(dkg): figure out what we need to set the currentOffset and currentLimit to! Do we even need to do that?
//            self.tableView.reloadData()
//            
//            // make sure we also load the thumbnails in case some are missing
//            downloadSpritesInBackground()
//            
//        } else {
//            
//            // check cache first to see if we have the data already
//            let cachedResponse = db.getCachedResponse(APIType.ListPokemon, offset: currentOffset, limit: currentLimit)
//            if let response = cachedResponse {
//                busyIndicator?.showOverlay()
//
//                let resourceList = self.transformer.jsonToNamedAPIResourceList(response)
//                
//                maxPokemonCountAPI = resourceList?.count
//                loadDataFromResourceList(resourceList)
//
//            } else {
//                busyIndicator?.showOverlay()
//                downloadMoreDataInBackground()
//            }
//        }
    }
    
    //
    // NOTE(dkg):
    // The more Pokemon in the cache, the longer it takes to download additional pokemons.
    // The JSON parsing for the UITableView data takes quite a time when done in a loop for all Pokemons.
    // Possible solution could be to only parse data when the tableView requests a cell for display, 
    // and not parse it upfront for all pokemons in the list! That should speed up things for longer
    // lists (60+ pokemon).
    // Additional solution: put more data directly into additional table columns, so we can just query the DB
    // for those and don't have to parse any JSON when just displaying data for the PokemonCells.
    //
//    func downloadMoreDataInBackground() {
//        
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
//            
//            // check cache first to see if we have the data already
//            let cachedResponse = self.db.getCachedResponse(APIType.ListPokemon, offset: self.currentOffset, limit: self.currentLimit)
//            if let response = cachedResponse {
//                self.busyIndicator?.showOverlay()
//                
//                let resourceList = self.transformer.jsonToNamedAPIResourceList(response)
//                self.maxPokemonCountAPI = resourceList?.count
//                self.loadDataFromResourceList(resourceList)
//                
//            } else {
//                
//                if self.downloadingAlready {
//                    return
//                }
//                self.downloadingAlready = true
//                
//                self.dl.startDownloadPokemonList(self.currentOffset, limit: self.currentLimit, completed: { resourceList, error in
//                    log("done saving list - get individual pokemons now")
//                    self.downloadingAlready = false
//                    if error == APIError.NoError {
//                        self.maxPokemonCountAPI = resourceList?.count
//                        self.loadDataFromResourceList(resourceList)
//                    } else {
//                        dispatch_async(dispatch_get_main_queue(), {
//                            self.busyIndicator?.hideOverlayView()
//                            showErrorAlert(self, message: "Some Pokemon data could not be downloaded.\nReason: \(error.rawValue)", title: "Download Error")
//                            if self.requestedMoreData {
//                                self.requestedMoreData = false
//                                self.reloadTableData()
//                            }
//                        })
//                    }
//                })
//            }
//        });
//    }
    
//    func loadDataFromResourceList(resourceList: NamedAPIResourceList?) {
//        
//        let count = self.currentLimit // poor man's future.all/promise.all "solution"
//        var counter = 0
//        var errors = 0
//        
//        func done(errors: Int) {
//            log("done with all pokemon downloads")
//            dispatch_async(dispatch_get_main_queue(), {
//                self.requestedMoreData = false
//                self.downloadingAlready = false
//                
//                self.reloadTableData()
//                self.busyIndicator?.hideOverlayView()
//                
//                self.downloadSpritesInBackground()
//                
//                if errors > 0 {
//                    showErrorAlert(self, message: "Some Pokemon data could not be downloaded.", title: "Download Error")
//                }
//            })
//        }
//        
//        if let list = resourceList {
//            
//            // TODO(dkg): Should this be refactored so the individual download happens in the Downloader
//            //            right after the list was downloaded?
//            let results = list.results
//
//            for resource in results {
//                
//                autoreleasepool({
//                    // TODO(dkg): think about how to force to re-download data - maybe invalidate the cache after a time?
//                    let url = resource.url
//                    let id = dl.extractIdFromUrl(url)
//                    let cachedResponse = id != 0 ? db.getCachedResponse(APIType.Pokemon, id: id) : nil
//                    
//                    log("resource : \(id) - \(resource)")
//
//                    if let response = cachedResponse {
//                        log("already downloaded data for this id \(id)")
//                        counter += 1
//                        
//                        let temp = self.transformer.jsonToPokemonModel(response)
//                        log("success? \(temp != nil)")
//                        
//                        if (counter == count) {
//                            done(errors)
//                        }
//                    } else {
//                        log("download another pokemon from \(url)")
//                        // TODO(dkg): use a queue or something in order to not fire too many downloads at once!
//                        dl.downloadPokemon(url, completed: { pokemon, error in
//                            log("downloaded another pokemon from \(url)")
//                            counter += 1
//                            
//                            if error != APIError.NoError {
//                                errors += 1
//                            }
//                            
//                            if (counter == count) {
//                                done(errors)
//                            }
//                        })
//                    } // if
//                }) // autoreleasepool
//            } // for
//        } else {
//            log("Could not convert JSON to NamedAPIResourceList.")
//            // TODO(dkg): report to user?
//        }
//    }
//    
//    func downloadSpritesInBackground() {
//        log("downloadSpritesInBackground")
//        if downloadingSpritesInBackground {
//            return
//        }
//
//        downloadingSpritesInBackground = true
//        
//        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { [unowned self] in
//            autoreleasepool({
//                self.downloadSprites()
//            })
//        }
//        
//    }
//    
//    func downloadSprites() {
//        log("downloadSprites")
//        
//        if self.downloadingSpritesAlready {
//            log("not downloading sprites now - already doing it")
//            return
//        }
//        self.downloadingSpritesAlready = true
//        
//        let pokemonData = db.loadPokemons() // "global" data object might not be up-to-date right now
//        
//        let count = pokemonData.count
//        var counter = 0
//        var errors = 0
//        
//        func done(errors: Int) {
//            log("done downloading sprites")
//            dispatch_async(dispatch_get_main_queue(), {
//                
//                self.downloadingSpritesInBackground = false
//                self.downloadingSpritesAlready = false
//                self.reloadTableData()
//                self.busyIndicator?.hideOverlayView()
//                
//                if errors > 0 {
//                    showErrorAlert(self, message: "Could not download some Pokemon sprites.")
//                }
//            })
//        }
//        
//        for pokemonJson in pokemonData {
//            autoreleasepool({
////                self.busyIndicator?.showOverlay()//TODO(dkg): when we are in a background thread then this is not good!
//                
//                if let _ = dl.getPokemonSpriteFromCache(pokemonJson) {
//                    
//                    counter += 1
//                    if counter == count {
//                        done(errors)
//                    }
//
//                } else {
//                    
//                    dl.downloadPokemonSprite(pokemonJson, completed: { (sprite, type, error) in
//                        
//                        if error != APIError.NoError {
//                            errors += 1
//                        }
//                        
//                        counter += 1
//                        
//                        if counter == count {
//                            done(errors)
//                        }
//
//                    }) // download
//                } // if
//            }) // autoreleasepool
//        }
//    }
    
//    func reloadTableData(searchTerm: String? = nil) {
//        busyIndicator?.showOverlay()
//        
//        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
//        dispatch_after(delayTime, dispatch_get_main_queue()) {
//            autoreleasepool({
//                if let searchTerm = searchTerm {
//                    self.data = self.db.loadPokemonsWithFilter(searchTerm)
//                } else {
//                    self.data = self.db.loadPokemons()
//                }
//                self.busyIndicator?.hideOverlayView()
//                let count = self.data!.count // db.getPokemonCount()
//                if self.displaySearchResults {
//                    self.title = "Found \(count) Pokemons"
//                } else {
//                    self.title = "\(count) Pokemons"
//                }
//            })
//            // make sure we are actually visible, otherwise don't bother
//            if self.isViewLoaded() && self.view.window != nil {
//                self.tableView.reloadData()
//            }
//        }
//    }
    
    // tableView callbacks
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let maxCount = maxPokemonCountAPI == nil ? -1 : maxPokemonCountAPI!
        if let theData = self.data {
            if (theData.count >= maxCount && maxCount > 0) || displaySearchResults  {
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
        let maxCount = maxPokemonCountAPI == nil ? -1 : maxPokemonCountAPI!
        
        if (!displaySearchResults) && ((indexPath.row == count && count < maxCount && maxCount > 0) || (count == 0 && maxCount == -1)) {
            // "loading" cell
            let cell: PokemonTableLoadMoreCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER_LOAD_MORE) as! PokemonTableLoadMoreCell
            
            if !requestedMoreData {

                requestedMoreData = true
                
                if count > 0 {
                    // NOTE(dkg): need to increment the offset until we are at the right position
                    let rest = count % currentLimit
                    let start = count - rest
                    
                    if currentOffset < start {
                        currentOffset = start
                        while currentOffset < start {
                            currentOffset += currentLimit
                        }
                    } else {
                        currentOffset += currentLimit
                    }
                    
                    // sanity checks
                    if currentOffset < 0 {
                        currentOffset = 0
                    } else if currentOffset > maxCount && maxCount > 0 {
                        currentOffset = maxCount - currentLimit
                    }
                }

//                busyIndicator?.showOverlay()
//                downloadMoreDataInBackground()
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
                assert(false, "this should not happen")
            }
            
            return cell
        }
    }
//    
//    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//        log("Tapped on cell at \(indexPath)")
//        
//        if let pokemonData = data {
//            let pokemonJson = pokemonData[indexPath.row]
//            let vc: PokemonDetailViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PokemonDetailViewController") as! PokemonDetailViewController
//            self.navigationController?.pushViewController(vc, animated: true, completion: { () in
//                vc.setPokemonDataJson(pokemonJson)
//            })
//        }
//    }
//    
//    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
//        log("editActionsForRowAtIndexPath \(indexPath)")
//        // NOTE(dkg): Maybe use a 3rd party library for this instead, that allows swipes in all directions and has different
//        //            animation options for the swipe, e.g. https://github.com/MortimerGoro/MGSwipeTableCell
//
//        if let pokemonData = data {
//            let pokemonJson = pokemonData[indexPath.row]
//            let pokemon = self.transformer.jsonToPokemonModel(pokemonJson)!
//            let isFav = db.isPokemonFavorite(pokemon.id)
//            let title = isFav ? "Un-Favorite" : "Favorite"
//            
//            let favorite = UITableViewRowAction(style: .Normal, title: title) { action, indexPath in
//                if let pokemonData = self.data {
//                    let pokemonJson = pokemonData[indexPath.row]
//                    let pokemon = self.transformer.jsonToPokemonModel(pokemonJson)!
//                    let isFavReverse = !self.db.isPokemonFavorite(pokemon.id)
//                    let title = isFavReverse ? "Un-Favorite" : "Favorite"
//                    
//                    self.db.updatePokemonFavoriteStatus(pokemon.id, isFavorite: isFavReverse)
//                    
//                    action.title = title
//                    
//                    self.tableView.setEditing(false, animated: true)
//                }
//            }
//            favorite.backgroundColor = UIColor.orangeColor()
//            
//            return [favorite]
//        } else {
//            return []
//        }
//    }
//    
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        logWarn("didReceiveMemoryWarning")
//    }
//    
//    // UISearchBarDelegate callbacks
//    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
//        log("textdidchange \(searchText)")
//        executeOrCancelSearch(searchText)
//    }
//    
//    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
//        log("searchBarCancelButtonClicked")
//        searchBar.resignFirstResponder()
//        executeOrCancelSearch()
//    }
//    
//    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
//        log("searchBarSearchButtonClicked")
//        executeOrCancelSearch(searchBar.text)
//    }
//    
//    func executeOrCancelSearch(term: String? = nil) {
//        log("executeOrCancelSearch(\(term))")
//        
//        // NOTE(dkg): need the dispatch because of keyboard not disappearing when resignFirstResponder is
//        //            called on the same run-loop iteration
//        // http://stackoverflow.com/a/22177234/193165 ==> Just resign the first responder but in the next run loop
//        
//        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
//        dispatch_after(delayTime, dispatch_get_main_queue()) {
//            if let term = term {
//                self.displaySearchResults = !term.isEmpty
//                if term.isEmpty {
//                    self.searchBar?.endEditing(true)
//                    self.searchBar?.resignFirstResponder()
//                }
//                self.reloadTableData(term.isEmpty ? nil : term)
//            } else {
//                self.displaySearchResults = false
//                self.searchBar?.endEditing(true)
//                self.searchBar?.resignFirstResponder()
//                self.reloadTableData()
//            }
//        }
//    }

}
