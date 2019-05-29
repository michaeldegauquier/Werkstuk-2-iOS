//
//  ViewController.swift
//  Werkstuk2
//
//  Created by student on 08/04/2019.
//  Copyright © 2019 student. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class ViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var myMapView: MKMapView!
    var locationManager = CLLocationManager()
    let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var record: Record!
    var recordList: [Record] = []
    var points: [MKMapPoint] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        checkFirstStartup()
        getAll()
        getRecordsFromCoreData()
    }
    
    func checkFirstStartup()
    {
        let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        if launchedBefore
        {
            print("Not first startup")
        }
        else
        {
            print("First startup")
            getRecordsFromCoreData()
            UserDefaults.standard.set(true, forKey: "launchedBefore")
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        let center = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let lineView = MKPolylineRenderer(overlay: overlay)
            lineView.strokeColor = UIColor.red
            lineView.lineWidth = CGFloat(5)
            return lineView
        }
        return MKOverlayRenderer()
    }
    
    func getAll() {
        let url = URL(string: "https://opendata.brussels.be/api/records/1.0/search/?dataset=traffic-volume&facet=level_of_service")
        let urlRequest = URLRequest(url: url!)
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            guard error == nil else {
                print("error calling GET")
                print(error!)
                return
            }
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: AnyObject] else {
                    print("Cannot convert json to string")
                    return
                }
                
                let records = json["records"] as! [AnyObject]
                
                //Records
                for record in records {
                    //datasetid
                    let datasetid = record["datasetid"] as! String
                    print(datasetid)
                    
                    //recordid
                    let recordid = record["recordid"] as! String
                    print(recordid)
                    
                    //fields Object------------
                    let fields = record["fields"] as AnyObject
                    
                    //--Geo_shape Object------------
                    let geo_shape = fields["geo_shape"] as AnyObject
                    
                    //----type
                    let typeGeoshape = geo_shape["type"] as! String
                    print(typeGeoshape)
                    
                    //--coordinates
                    //let coordinatesGeoshape = geo_shape["coordinates"] as! NSArray
                    
                    /*
                    for coordinates in coordinatesGeoshape {
                        print(coordinates[0][0][0])
                    }
                    */
                    
                    let coordinatesGeoshape = (geo_shape as AnyObject).value(forKey: "coordinates") as? [NSArray]
                    for i in 0...coordinatesGeoshape!.count - 1 {
                        let c1 = coordinatesGeoshape![i][0] as! Double
                        let c2 = coordinatesGeoshape![i][1] as! Double
                        print(c1)
                        print(c2)
                    }
                    
                    
                    //--level_of_service
                    let level_of_service = fields["level_of_service"] as! String
                    print(level_of_service)
         
                    //--geo_point_2d
                    let geo_point_2d = fields["geo_point_2d"] as! NSArray
                    //----geo_point_2d_latitude
                    let geo_point_2d_lat = geo_point_2d[0] as! Double
                    print(geo_point_2d_lat)
                    //----geo_point_2d_longitude
                    let geo_point_2d_long = geo_point_2d[1] as! Double
                    print(geo_point_2d_long)
                    
                    //--level
                    let level = fields["level"] as! String
                    print(level)
                    
                    //geometry Object------------
                    let geometry = record["geometry"] as AnyObject
                    
                    //--type
                    let typeGeometry = geometry["type"] as! String
                    print(typeGeometry)
                    
                    //--coordinates
                    let coordinatesGeometry = geometry["coordinates"] as! NSArray
                    //----coordinates longitude
                    let coordinates_long = coordinatesGeometry[0] as! Double
                    print(coordinates_long)
                    //----coordniates latitude
                    let coordinates_lat = coordinatesGeometry[1] as! Double
                    print(coordinates_lat)
                    
                    //record_timestamp
                    let record_timestamp = record["record_timestamp"] as! String
                    print(record_timestamp)
                    
                    DispatchQueue.main.async {
                        self.showAlert((Any).self, record_timestamp: record_timestamp)
                        
                        self.saveRecordToCoreData(datasetid: datasetid, recordid: recordid, typeGeoshape: typeGeoshape, coordinatesGeoshape: coordinatesGeoshape!, levelOfService: level_of_service, geoPoint2dLat: geo_point_2d_lat, geoPoint2dLong: geo_point_2d_long, level: level, typeGeometry: typeGeometry, coordLat: coordinates_lat, coordLong: coordinates_long, timestamp: record_timestamp)
                        let polyline = MKPolyline(points: self.points, count: self.points.count)
                        self.myMapView.addOverlay(polyline)
                    }
                    
                }
                
                DispatchQueue.main.async {
                    //let polyline = MKPolyline(points: self.points, count: self.points.count)
                    //self.myMapView.addOverlay(polyline)
                }
            } catch {
                print("Some error: \(error)")
            }
        }
        task.resume()
    }
    
    func saveRecordToCoreData(datasetid: String, recordid: String, typeGeoshape: String, coordinatesGeoshape: [NSArray], levelOfService: String, geoPoint2dLat: Double, geoPoint2dLong: Double, level: String, typeGeometry: String, coordLat: Double, coordLong: Double, timestamp: String) {
        let record = NSEntityDescription.insertNewObject(forEntityName: "Record", into: managedContext) as? Record
        record!.datasetid = datasetid
        record!.recordid = recordid
        
        record!.fields?.geo_shape?.type = typeGeoshape
        record!.fields?.geo_shape?.coordinates = coordinatesGeoshape as NSObject
        record!.fields?.level_of_service = levelOfService
        record!.fields?.geo_point_2d_lat = geoPoint2dLat
        record!.fields?.geo_point_2d_long = geoPoint2dLong
        record!.fields?.level = level
        
        record!.geometry?.type = typeGeometry
        record!.geometry?.coordinates_lat = coordLat
        record!.geometry?.coordinates_long = coordLong
        
        record!.record_timestamp = timestamp
        
        for i in 0...coordinatesGeoshape.count - 1 {
            let c1 = coordinatesGeoshape[i][0] as! Double
            let c2 = coordinatesGeoshape[i][1] as! Double
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: c2, longitude: c1))
            points.append(point)
        }
        
        recordList.append(record!)
        
        do {
            try managedContext.save()
        } catch {
            fatalError("Cannot save to core data: \(error)")
        }
        
    }
    
    func getRecordsFromCoreData() {
        
        let recordFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Record")
        
        do {
            recordList = try managedContext.fetch(recordFetch) as! [Record]
        }
        catch {
            print("Cannot fetch: \(error)")
        }
    }
    
    func showAlert(_ sender: Any, record_timestamp: String) {
        let alertController = UIAlertController(title: "Traffic time", message:
            record_timestamp, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func refresh_button(_ sender: Any) {
        getAll()
    }
}

//Simplified ios. Get a specific value from a big JSON response.
//https://codereview.stackexchange.com/questions/175872/get-a-specific-value-from-a-big-json-response
//Geraadpleegd op 28 mei 2019

//Stackexchange. Swift JSON Tutorial – Fetching and Parsing JSON from URL.
//https://www.simplifiedios.net/swift-json-tutorial/
//Geraadpleegd op 28 mei 2019

//Stackoverflow. Detect first launch of ios app
//https://stackoverflow.com/questions/27208103/detect-first-launch-of-ios-app
//Geraadpleegd op 28 mei 2019

//Medium. Core data swift 4 for beginners
//https://medium.com/xcblog/core-data-with-swift-4-for-beginners-1fc067cca707
//Geraadpleegd op 28 mei 2019

//ioscreator. display alert ios tutorial
//https://www.ioscreator.com/tutorials/display-alert-ios-tutorial
//Geraadpleegd op 28 mei 2019


