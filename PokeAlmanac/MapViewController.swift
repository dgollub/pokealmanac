//
//  MapViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation


private let ANNOTATION_POKEMON_RESUSE_IDENTIFIER = "pokemonAnnotationViewReuseIdentifier"
private let ANNOTATION_DEFAULT_RESUSE_IDENTIFIER = "defaultAnnotationViewReuseIdentifier"

private let BUTTON_TAG_ATTACK = 1
private let BUTTON_TAG_CATCH = 2


public class PokemonAnnotation : NSObject, MKAnnotation {
    
    public let pokemon: Pokemon
    public var coordinate: CLLocationCoordinate2D
    public let title: String?
    public let subtitle: String?
    public let image: UIImage?
    public var found: NSDate?
    
    public init(coordinate: CLLocationCoordinate2D, pokemon: Pokemon, image: UIImage? = nil, found: NSDate? = nil) {
        self.pokemon = pokemon
        self.coordinate = coordinate
        self.title = pokemon.name.capitalizedString
        self.subtitle = "Weight: \(pokemon.weight), Height: \(pokemon.height)"
        
        if let image = image {
            self.image = image
        } else {
            self.image = UIImage(named: "IconUnknownPokemon")
        }
        
        self.found = found
    }
}

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var buttonScanMap: UIBarButtonItem?
    @IBOutlet weak var buttonActionSheet: UIBarButtonItem?
    @IBOutlet weak var mapView: MKMapView?
    
    var locationManager: CLLocationManager?
    var initialLocation: CLLocation?
//    var geoCoder: CLGeocoder?
    
    var pokemonAnnotations: [PokemonAnnotation] = []
    
    let busyIndicator = BusyOverlay()
    
    var centerMapFirstTime: dispatch_once_t = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("MapViewController")
        
        busyIndicator.showOverlay()
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // set center to Akihabara
        initialLocation = CLLocation(latitude: 35.7021, longitude: 139.7753) // CLLocationDegrees
        
        mapView?.delegate = self
//        geoCoder = CLGeocoder()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        log("viewWillAppear")

        locationManager?.requestWhenInUseAuthorization()
        mapView?.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        logWarn("didReceiveMemoryWarning")
    }

    @IBAction func showActionSheet(sender: AnyObject) {
        log("showActionSheet")
        let actionSheet = UIAlertController(title: "Choose", message: "What do you want to do?", preferredStyle: .ActionSheet)
        
        let resetLocationAction = UIAlertAction(title: "Reset Location", style: .Default) { (action) in
            self.zoomInToLocation(self.initialLocation)
        }
        actionSheet.addAction(resetLocationAction)
        
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus != CLAuthorizationStatus.AuthorizedAlways &&
           authStatus != CLAuthorizationStatus.AuthorizedWhenInUse {
            
            let askForLocationAction = UIAlertAction(title: "Allow your location", style: .Default) { (action) in
                self.locationManager?.requestWhenInUseAuthorization()
            }
            actionSheet.addAction(askForLocationAction)
        }
        
        let scanAction = UIAlertAction(title: "Scan Map", style: .Default) { (action) in
            self.scanMap(action)
        }
        actionSheet.addAction(scanAction)
        
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        actionSheet.addAction(cancelAction)
        
        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func scanMap(sender: AnyObject) {
        log("scanMap")
        self.setupPokemonsOnMap(self.initialLocation)
    }
    
    func zoomInToLocation(selectedLocation: CLLocation?) {
        if let location = selectedLocation {
            let coords = location.coordinate
            let mapRegion = MKCoordinateRegionMakeWithDistance(coords, 50, 50)
            
            self.mapView?.setCenterCoordinate(coords, animated: true)
            self.mapView?.setRegion(mapRegion, animated: true)
        }
    }
    
    func setupPokemonsOnMap(aLocation: CLLocation? = nil) {
        
        log("setupPokemonsOnMap")
        // if we have already set up pokemons for this map, don't set up more
        // there should be a radius of 100m (or 500m or whatever) in which we allow
        // pokemons to show up, but that's it - if the user zooms out too much we
        // do not add more pokemons - this scanner is not that strong
        
        var pokemonsToAdd: Int = randomInt(1...4)
        if pokemonAnnotations.count == 0 || pokemonAnnotations.count < 4 {
            // have at least 3 pokemon on the map at any time
            pokemonsToAdd = 4 - pokemonAnnotations.count
        } else if pokemonAnnotations.count > 10 {
            pokemonsToAdd = 0
        }
        
        var location: CLLocation? = aLocation
        
        if let _ = location {} else {
            location = self.initialLocation
        }

        if pokemonsToAdd > 0 {
            if let location = location {
                
                var left = 0
                
                self.busyIndicator.showOverlay()
                
                let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
                dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                
                    let dl = Downloader()
                    let pokemonsJsons = DB().loadPokemons()
                    let transformer = Transformer()
                    
                    for _ in 1...pokemonsToAdd {
                        let index = randomInt(0...pokemonsJsons.count - 1)
                        let pokemon = transformer.jsonToPokemonModel(pokemonsJsons[index])!
                        
                        let pokemonCoords = self.getRandomCoordinates(location.coordinate)
                        
                        if let image = dl.getPokemonSpriteFromCache(pokemon) {
                            let annotation = PokemonAnnotation(coordinate: pokemonCoords, pokemon: pokemon, image: image)
                            self.pokemonAnnotations.append(annotation)
                        
                            // put the annotation on the map
                            self.mapView?.addAnnotation(annotation)
                        } else {
                            left += 1
                            
                            dl.downloadPokemonSprite(pokemon, completed: { (error) in
                                // ignore
                            })
                            
                        }
                    }
                    
                    if left > 0 {
                        self.setupPokemonsOnMap(location)
                    }
                    
                    self.busyIndicator.hideOverlayView()
                })

            }
        }
    }
    
    func getRandomCoordinates(fromCoords: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let randomMeters = randomInt(5...120)
        let randomBearing = randomInt(0...359)
        
        let coords = self.locationWithBearing(Double(randomBearing), distanceMeters: Double(randomMeters), origin: fromCoords)
        return coords
    }

    // from http://stackoverflow.com/a/31127466/193165
    func locationWithBearing(bearing: Double, distanceMeters: Double, origin: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let distRadians = distanceMeters / (6372797.6)
        
        let rbearing = bearing * M_PI / 180.0
        
        let lat1 = origin.latitude * M_PI / 180
        let lon1 = origin.longitude * M_PI / 180
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(rbearing))
        let lon2 = lon1 + atan2(sin(rbearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180 / M_PI, longitude: lon2 * 180 / M_PI)
    }
    
    // CLLocationManagerDelegate callbacks
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        logWarn("CLLocationManager failed: \(error)")
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        log("didChangeAuthorizationStatus: \(status.rawValue) \(status)")

        switch (status) {
        case .Denied:
            fallthrough
        case .Restricted:
            showErrorAlert(self, message: "Please enable location services in the Settings app.", title: "Location Disabled")
            return
        case .NotDetermined:
            break
        case .AuthorizedAlways:
            fallthrough
        case .AuthorizedWhenInUse:
            self.mapView?.showsUserLocation = true
            break
        }
    }
    
    // MKMapViewDelegate callbacks
    func mapViewDidFinishLoadingMap(mapView: MKMapView) {
        log("mapViewDidFinishLoadingMap")
        
        busyIndicator.hideOverlayView()
    }
    
    func mapView(mapView: MKMapView, didFailToLocateUserWithError error: NSError) {
        logWarn("didFailToLocateUserWithError \(error)")
        
        if let _ = self.presentedViewController {
            //
        } else {
            var msg = "Unknown error"
            if let err = CLError(rawValue: error.code) {
                msg = err == CLError.LocationUnknown ? "Sorry, could not find your location." : "Error while finding your location."
            }
            showErrorAlert(self, message: msg, title: "Error")
        }
    }
    
    func mapView(mapView: MKMapView, didUpdateUserLocation userLocation: MKUserLocation) {
        log("didUpdateUserLocation: \(userLocation)")
        
        dispatch_once(&centerMapFirstTime) {
            if let location = userLocation.location {
                self.initialLocation = location
            }
            self.zoomInToLocation(userLocation.location)
            
//            let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
//            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
//                self.setupPokemonsOnMap(userLocation.location)
//            })
        }
    }
    
    func mapViewDidFinishRenderingMap(mapView: MKMapView, fullyRendered: Bool) {
        log("mapViewDidFinishRenderingMap \(fullyRendered)")
        if fullyRendered {
            self.setupPokemonsOnMap(self.initialLocation)
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var view: MKAnnotationView? = nil

        if let pokemonAnnotation: PokemonAnnotation = annotation as? PokemonAnnotation {
            view = mapView.dequeueReusableAnnotationViewWithIdentifier(ANNOTATION_POKEMON_RESUSE_IDENTIFIER)
            if let view = view {
                view.annotation = annotation
            } else {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: ANNOTATION_POKEMON_RESUSE_IDENTIFIER)
            }

            view?.image = pokemonAnnotation.image
            view?.canShowCallout = true
            
            let buttonCatch = UIButton(type: .DetailDisclosure) // .Custom does not show!
            buttonCatch.setImage(UIImage(named: "IconFrisbee"), forState: .Normal)
            buttonCatch.setImage(UIImage(named: "IconFrisbeeFilled"), forState: .Selected)
            buttonCatch.userInteractionEnabled = true
            buttonCatch.tag = BUTTON_TAG_CATCH
            
            view?.rightCalloutAccessoryView = buttonCatch
            
            let buttonAttack = UIButton(type: .DetailDisclosure) // .Custom does not show!
            buttonAttack.setImage(UIImage(named: "IconBaseball"), forState: .Normal)
            buttonAttack.setImage(UIImage(named: "IconBaseballFilled"), forState: .Selected)
            buttonAttack.userInteractionEnabled = true
            buttonAttack.tag = BUTTON_TAG_ATTACK
            
            view?.leftCalloutAccessoryView = buttonAttack
            
        } else {
            view = mapView.dequeueReusableAnnotationViewWithIdentifier(ANNOTATION_DEFAULT_RESUSE_IDENTIFIER)
            if view == nil {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: ANNOTATION_DEFAULT_RESUSE_IDENTIFIER)
            }
            view?.canShowCallout = true
        }

        return view
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let pokemonAnnotation: PokemonAnnotation = view.annotation as? PokemonAnnotation {
            log("\(pokemonAnnotation.pokemon.name)")
            if control.tag == BUTTON_TAG_ATTACK {
                attackPokemon(pokemonAnnotation)
            } else if control.tag == BUTTON_TAG_CATCH {
                catchPokemon(pokemonAnnotation)
            }
        }
    }
    
    func attackPokemon(annotation: PokemonAnnotation) {
        // check if we have any pokemons in our backpack first.
        let backpack = DB().loadPokemonsFromBackpackAsPokemonAnnotations()
        let count = backpack.count
        if count > 0 {
            let actionSheet = UIAlertController(title: "Choose", message: "Which Pokemon do you want to use in the battle against \(annotation.pokemon.name.capitalizedString)?", preferredStyle: .ActionSheet)
            
            // TODO(dkg): Implement real battle system here. Obviously. :-)
            
            var alreadySelected: [Int] = []
            let numberOfPokemonsToChooseFrom = count > 3 ? 3 : count
            for _ in 1...numberOfPokemonsToChooseFrom {
                var rndIndex = randomInt(0...count - 1)
                // make sure we only include a given pokemon once in the selection "screen"
                while let _ = alreadySelected.indexOf(rndIndex) {
                    rndIndex = randomInt(0...count - 1)
                }
                alreadySelected.append(rndIndex)
                
                let pokemon = backpack[rndIndex].pokemon
                let pokemonToAttachWithAction = UIAlertAction(title: "Choose \(pokemon.name.capitalizedString)", style: .Default) { (action) in
                    
                    let winChance = randomInt(0...50) // TODO(dkg): use actual PokemonSpecies.capture_rate for this!
                    let playerChance = randomInt(0...100)
                    
                    if playerChance <= winChance {
                        self.putCaughtPokemonInBackpack(annotation,
                                                        message: "You chose wisely and caught \(annotation.pokemon.name.capitalizedString).\nCongratulations!\nYou put it in your backpack.",
                                                        title: "You Won!")
                        
                    } else {
                        showErrorAlert(self, message: "You chose ... poorly.\n", title: "You Lost!", completion: {
                            self.runAwayPokemon(annotation, message: "The \(annotation.pokemon.name.capitalizedString) ran away.", title: "Oh dear!")
                        })
                    }
                }
                actionSheet.addAction(pokemonToAttachWithAction)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            actionSheet.addAction(cancelAction)
            
            self.presentViewController(actionSheet, animated: true, completion: nil)
        } else {
            showErrorAlert(self, message: "You will need to catch at least one Pokemon first before you can battle others!", title: "No Pokemon!")
        }
    }
    
    func catchPokemon(annotation: PokemonAnnotation) {
        let chance = randomInt(0...100)
        let pokemon = annotation.pokemon
        let actionSheet = UIAlertController(title: "Catch \(pokemon.name.capitalizedString)?", message: "You have a \(chance)% chance to succeed.", preferredStyle: .ActionSheet)
        
        let tryCatchAction = UIAlertAction(title: "Try!", style: .Default) { (action) in
            let catchChance = randomInt(0...100)
            if catchChance <= chance && chance > 0 {
                
                self.putCaughtPokemonInBackpack(annotation,
                                                message: "You successfully caught \(pokemon.name.capitalizedString).\nCongratulations!\nYou put it in your backpack.",
                                                title: "You got it!")

            } else {
                showErrorAlert(self, message: "You failed.", title: ":-(", completion: {
                    self.runAwayPokemon(annotation, message: "The \(pokemon.name.capitalizedString) ran away.", title: "Oh dear!")
                })
            }
        }
        actionSheet.addAction(tryCatchAction)
        
        let leaveAction = UIAlertAction(title: "Leave?", style: .Cancel) { (action) in
            self.runAwayPokemon(annotation, message: "The Pokemon was startled by your noise when you left.", title: "Oh no!")
        }
        actionSheet.addAction(leaveAction)
        
        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
    
    func putCaughtPokemonInBackpack(annotation: PokemonAnnotation, message: String, title: String) {
        self.mapView?.removeAnnotation(annotation)
        let index = self.pokemonAnnotations.indexOf(annotation)
        self.pokemonAnnotations.removeAtIndex(index!)
        
        let pokemon = annotation.pokemon
        let coords = annotation.coordinate
        DB().savePokemonInBackpack(pokemon, latitude: coords.latitude, longitude: coords.longitude)
        
        // TODO(dkg): put pokemon in backpack!
        showErrorAlert(self, message: message, title: title, completion: {
            
            if self.pokemonAnnotations.count == 0 {
                self.scanMap(annotation)
            }
        })
    }
    
    func runAwayPokemon(annotation: PokemonAnnotation, message: String, title: String) {
        // there is a chance that the pokemon will run away anyway
        let runAwayChance = randomInt(0...100)
        if runAwayChance > 65 {
            showErrorAlert(self, message: message, title: title, completion: {
                let coords = annotation.coordinate
                let newCoords = self.getRandomCoordinates(coords)
                
                self.mapView?.removeAnnotation(annotation)
                
                annotation.coordinate = newCoords
                
                self.mapView?.addAnnotation(annotation)
            })
        } else {
            self.mapView?.deselectAnnotation(annotation, animated: true)
        }

    }
    
}

