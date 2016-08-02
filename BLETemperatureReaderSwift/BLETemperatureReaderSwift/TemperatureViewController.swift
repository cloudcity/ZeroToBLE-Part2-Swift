//
//  TemperatureViewController.swift
//  iOSRemoteConfBLEDemo
//
//  Created by Evan Stone on 4/9/16.
//  Copyright © 2016 Cloud City. All rights reserved.
//

import UIKit
import CoreBluetooth

// Conform to CBCentralManagerDelegate, CBPeripheralDelegate protocols
class TemperatureViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var backgroundImageView1: UIImageView!
    @IBOutlet weak var backgroundImageView2: UIImageView!
    @IBOutlet weak var controlContainerView: UIView!
    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var disconnectButton: UIButton!
    
    // define our scanning interval times
    let timerPauseInterval:NSTimeInterval = 10.0
    let timerScanInterval:NSTimeInterval = 2.0
    
    // UI-related
    let temperatureLabelFontName = "HelveticaNeue-Thin"
    let temperatureLabelFontSizeMessage:CGFloat = 56.0
    let temperatureLabelFontSizeTemp:CGFloat = 81.0
    
    var backgroundImageViews: [UIImageView]!
    var visibleBackgroundIndex = 0
    var invisibleBackgroundIndex = 1
    var lastTemperatureTens = 0
    let defaultInitialTemperature = -9999
    var lastTemperature:Int!
    var lastHumidity:Double = -9999
    var circleDrawn = false
    var keepScanning = false
    //var isScanning = false
    
    // Core Bluetooth properties
    var centralManager:CBCentralManager!
    var sensorTag:CBPeripheral?
    var temperatureCharacteristic:CBCharacteristic?
    var humidityCharacteristic:CBCharacteristic?
    
    // This could be simplified to "SensorTag" and check if it's a substring.
    // (Probably a good idea to do that if you're using a different model of
    // the SensorTag, or if you don't know what model it is...)
    let sensorTagName = "CC2650 SensorTag"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lastTemperature = defaultInitialTemperature

        // Create our CBCentral Manager
        // delegate: The delegate that will receive central role events. Typically self.
        // queue:    The dispatch queue to use to dispatch the central role events. 
        //           If the value is nil, the central manager dispatches central role events using the main queue.
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Central Manager Initialization Options (Apple Developer Docs): http://tinyurl.com/zzvsgjh
        //  CBCentralManagerOptionShowPowerAlertKey
        //  CBCentralManagerOptionRestoreIdentifierKey
        //      To opt in to state preservation and restoration in an app that uses only one instance of a 
        //      CBCentralManager object to implement the central role, specify this initialization option and provide
        //      a restoration identifier for the central manager when you allocate and initialize it.
        //centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // configure initial UI
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Searching"
        humidityLabel.text = ""
        humidityLabel.hidden = true
        circleView.hidden = true
        backgroundImageViews = [backgroundImageView1, backgroundImageView2]
        view.bringSubviewToFront(backgroundImageViews[0])
        backgroundImageViews[0].alpha = 1
        backgroundImageViews[1].alpha = 0
        view.bringSubviewToFront(controlContainerView)
    }
    
    override func viewWillAppear(animated: Bool) {
        if lastTemperature != defaultInitialTemperature {
            updateTemperatureDisplay()
        }
    }
    
    
    // MARK: - Handling User Interaction
    
    @IBAction func handleDisconnectButtonTapped(sender: AnyObject) {
        // if we don't have a sensor tag, start scanning for one...
        if sensorTag == nil {
            keepScanning = true
            resumeScan()
            return
        } else {
            disconnect()
        }
    }
    
    func disconnect() {
        if let sensorTag = self.sensorTag {
            if let tc = self.temperatureCharacteristic {
                sensorTag.setNotifyValue(false, forCharacteristic: tc)
            }
            if let hc = self.humidityCharacteristic {
                sensorTag.setNotifyValue(false, forCharacteristic: hc)
            }
            
            /*
             NOTE: The cancelPeripheralConnection: method is nonblocking, and any CBPeripheral class commands
             that are still pending to the peripheral you’re trying to disconnect may or may not finish executing.
             Because other apps may still have a connection to the peripheral, canceling a local connection
             does not guarantee that the underlying physical link is immediately disconnected.
             
             From your app’s perspective, however, the peripheral is considered disconnected, and the central manager
             object calls the centralManager:didDisconnectPeripheral:error: method of its delegate object.
             */
            centralManager.cancelPeripheralConnection(sensorTag)
        }
        temperatureCharacteristic = nil
        humidityCharacteristic = nil
    }
    
    
    // MARK: - Bluetooth scanning
    
    func pauseScan() {
        // Scanning uses up battery on phone, so pause the scan process for the designated interval.
        print("*** PAUSING SCAN...")
        _ = NSTimer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
        centralManager.stopScan()
        disconnectButton.enabled = true
    }
    
    func resumeScan() {
        if keepScanning {
            // Start scanning again...
            print("*** RESUMING SCAN!")
            disconnectButton.enabled = false
            temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
            temperatureLabel.text = "Searching"
            _ = NSTimer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            centralManager.scanForPeripheralsWithServices(nil, options: nil)
        } else {
            disconnectButton.enabled = true
        }
    }
    
    
    // MARK: - Updating UI
    
    func updateTemperatureDisplay() {
        if !circleDrawn {
            drawCircle()
        } else {
            circleView.hidden = false
        }
        
        updateBackgroundImageForTemperature(lastTemperature)
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeTemp)
        temperatureLabel.text = " \(lastTemperature)°"
    }

    func drawCircle() {
        circleView.hidden = false
        let circleLayer = CAShapeLayer()
        circleLayer.path = UIBezierPath(ovalInRect: CGRectMake(0, 0, circleView.frame.width, circleView.frame.height)).CGPath
        circleView.layer.addSublayer(circleLayer)
        circleLayer.lineWidth = 2
        circleLayer.strokeColor = UIColor.whiteColor().CGColor
        circleLayer.fillColor = UIColor.clearColor().CGColor
        circleDrawn = true
    }
    
    func tensValue(temperature:Int) -> Int {
        var temperatureTens = 10;
        if (temperature > 19) {
            if (temperature > 99) {
                temperatureTens = 100;
            } else {
                temperatureTens = 10 * Int(floor( Double(temperature / 10) + 0.5 ))
            }
        }
        return temperatureTens
    }
    
    func updateBackgroundImageForTemperature(temperature:Int) {
        let temperatureTens = tensValue(temperature)
        if temperatureTens != lastTemperatureTens {
            // generate file name of new background to show
            let temperatureFilename = "temp-\(temperatureTens)"
            print("*** BACKGROUND FILENAME: \(temperatureFilename)")
            
            // fade out old background, fade in new.
            let visibleBackground = backgroundImageViews[visibleBackgroundIndex]
            let invisibleBackground = backgroundImageViews[invisibleBackgroundIndex]
            invisibleBackground.image = UIImage(named: temperatureFilename)
            invisibleBackground.alpha = 0
            view.bringSubviewToFront(invisibleBackground)
            view.bringSubviewToFront(controlContainerView)
            UIView.animateWithDuration(0.5, animations: { 
                    invisibleBackground.alpha = 1;
                }, completion: { (finished) in
                    visibleBackground.alpha = 0
                    let indexTemp = self.visibleBackgroundIndex
                    self.visibleBackgroundIndex = self.invisibleBackgroundIndex
                    self.invisibleBackgroundIndex = indexTemp
                    print("**** NEW INDICES - visible: \(self.visibleBackgroundIndex) - invisible: \(self.invisibleBackgroundIndex)")
            })
        }
    }
    
    func updateHumidity() {
        
    }
    
    // MARK: - CBCentralManagerDelegate methods
    
    // Invoked when the central manager’s state is updated.
    func centralManagerDidUpdateState(central: CBCentralManager) {
        var showAlert = true
        var message = ""
        
        switch central.state {
        case .PoweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .Unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .Unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .Resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .Unknown:
            message = "The state of the BLE Manager is unknown."
        case .PoweredOn:
            showAlert = false
            message = "Bluetooth LE is turned on and ready for communication."
            
            print(message)
            keepScanning = true
            _ = NSTimer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            
            // Initiate Scan for Peripherals
            //Option 1: Scan for all devices
            //centralManager.scanForPeripheralsWithServices(nil, options: nil)
            
            // Option 2: Scan for devices that have the service you're interested in...
            let sensorTagAdvertisingUUID = CBUUID(string: Device.SensorTagAdvertisingUUID)
            print("Scanning for SensorTag adverstising with UUID: \(sensorTagAdvertisingUUID)")
            centralManager.scanForPeripheralsWithServices([sensorTagAdvertisingUUID], options: nil)

        }
        
        if showAlert {
            let alertController = UIAlertController(title: "Central Manager State", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil)
            alertController.addAction(okAction)
            self.showViewController(alertController, sender: self)
        }
    }
    
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys. 
     You must retain a local copy of the peripheral if any command is to be performed on it. 
     In use cases where it makes sense for your app to automatically connect to a peripheral that is 
     located within a certain range, you can use RSSI data to determine the proximity of a discovered 
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.

     */
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print("centralManager didDiscoverPeripheral - CBAdvertisementDataLocalNameKey is \"\(CBAdvertisementDataLocalNameKey)\"")

        // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("NEXT PERIPHERAL NAME: \(peripheralName)")
            print("NEXT PERIPHERAL UUID: \(peripheral.identifier.UUIDString)")
            
            if peripheralName == sensorTagName {
                print("SENSOR TAG FOUND! ADDING NOW!!!")
                // to save power, stop scanning for other devices
                keepScanning = false
                disconnectButton.enabled = true

                // save a reference to the sensor tag
                sensorTag = peripheral
                sensorTag!.delegate = self
                
                // Request a connection to the peripheral
                centralManager.connectPeripheral(sensorTag!, options: nil)
            }
        }
    }
    
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful. 
     You typically implement this method to set the peripheral’s delegate and to discover its services.
    */
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("**** SUCCESSFULLY CONNECTED TO SENSOR TAG!!!")
    
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Connected"
        
        // Now that we've successfully connected to the SensorTag, let's discover the services.
        // - NOTE:  we pass nil here to request ALL services be discovered.
        //          If there was a subset of services we were interested in, we could pass the UUIDs here.
        //          Doing so saves battery life and saves time.
        peripheral.discoverServices(nil)
    }
    
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.

     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete. 
     Because connection attempts do not time out, a failed connection usually indicates a transient issue, 
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("**** CONNECTION TO SENSOR TAG FAILED!!!")
    }
    

    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected. 
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error. 
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("**** DISCONNECTED FROM SENSOR TAG!!!")
        lastTemperature = 0
        updateBackgroundImageForTemperature(lastTemperature)
        circleView.hidden = true
        temperatureLabel.font = UIFont(name: temperatureLabelFontName, size: temperatureLabelFontSizeMessage)
        temperatureLabel.text = "Tap to search"
        humidityLabel.text = ""
        humidityLabel.hidden = true
        if error != nil {
            print("****** DISCONNECTION DETAILS: \(error!.localizedDescription)")
        }
        sensorTag = nil
    }
    
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method. 
     If the services of the peripheral are successfully discovered, you can access them 
     through the peripheral’s services property. 
     
     If successful, the error parameter is nil. 
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error != nil {
            print("ERROR DISCOVERING SERVICES: \(error?.localizedDescription)")
            return
        }

        // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                // If we found either the temperature or the humidity service, discover the characteristics for those services.
                if (service.UUID == CBUUID(string: Device.TemperatureServiceUUID)) ||
                    (service.UUID == CBUUID(string: Device.HumidityServiceUUID)) {
                    peripheral.discoverCharacteristics(nil, forService: service)
                }
            }
        }
    }
    
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property. 
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(error?.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Temperature Data Characteristic
                if characteristic.UUID == CBUUID(string: Device.TemperatureDataUUID) {
                    // Enable the IR Temperature Sensor notifications
                    temperatureCharacteristic = characteristic
                    sensorTag?.setNotifyValue(true, forCharacteristic: characteristic)
                }
                
                // Temperature Configuration Characteristic
                if characteristic.UUID == CBUUID(string: Device.TemperatureConfig) {
                    // Enable IR Temperature Sensor
                    var enableValue:UInt8 = 1
                    let enableBytes = NSData(bytes: &enableValue, length: sizeof(UInt8))
                    sensorTag?.writeValue(enableBytes, forCharacteristic: characteristic, type: .WithResponse)
                }
                
                if characteristic.UUID == CBUUID(string: Device.HumitidyDataUUID) {
                    // Enable Humidity Sensor notifications
                    humidityCharacteristic = characteristic
                    sensorTag?.setNotifyValue(true, forCharacteristic: characteristic)
                }
                
                if characteristic.UUID == CBUUID(string: Device.HumidityConfig) {
                    // Enable Humidity Temperature Sensor
                    var enableValue:UInt8 = 1
                    let enableBytes = NSData(bytes: &enableValue, length: sizeof(UInt8))
                    sensorTag?.writeValue(enableBytes, forCharacteristic: characteristic, type: .WithResponse)
                }

            }
        }
    }
    
    
    /*
     Invoked when you retrieve a specified characteristic’s value, 
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for 
     which notifications and indications are enabled has changed. 
     
     If successful, the error parameter is nil. 
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            print("ERROR ON UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(error?.localizedDescription)")
            return
        }
        
        // extract the data from the characteristic's value property and display the value based on the characteristic type
        if let dataBytes = characteristic.value {
            if characteristic.UUID == CBUUID(string: Device.TemperatureDataUUID) {
                calculateTemperature(dataBytes)
            } else if characteristic.UUID == CBUUID(string: Device.HumitidyDataUUID) {
                displayHumidity(dataBytes)
            }
        }
    }
    
    func displayHumidity(data:NSData) {
        let dataLength = data.length / sizeof(UInt16)
        var dataArray = [UInt16](count:dataLength, repeatedValue: 0)
        data.getBytes(&dataArray, length: dataLength * sizeof(Int16))
        
        for i in 0 ..< dataLength {
            let nextInt:UInt16 = dataArray[i]
            print("next int: \(nextInt)")
        }
        
        let rawHumidity:UInt16 = dataArray[Device.SensorDataIndexHumidity]
        let calculatedHumidity = calculateRelativeHumidity(rawHumidity)
        print("*** HUMIDITY: \(calculatedHumidity)");
        humidityLabel.text = String(format: "Humidity: %.01f%%", calculatedHumidity)
        humidityLabel.hidden = false
        
        // Humidity sensor also retrieves a temperature, which we don't use.
        // However, for instructional purposes, here's how to get at it to compare to the ambient sensor:
        let rawHumidityTemp:UInt16 = dataArray[Device.SensorDataIndexHumidityTemp]
        let calculatedTemperatureC = calculateHumidityTemperature(rawHumidityTemp)
        let calculatedTemperatureF = convertCelciusToFahrenheit(calculatedTemperatureC)
        print("*** HUMIDITY TEMP C: \(calculatedTemperatureC) F: \(calculatedTemperatureF)")
        
    }

    
    // MARK: - TI Sensor Tag Utility Methods
    
    func convertCelciusToFahrenheit(celcius:Double) -> Double {
        let fahrenheit = (celcius * 1.8) + Double(32)
        return fahrenheit
    }
    
    func calculateTemperature(data:NSData) {
        // We'll get four bytes of data back, so we divide the byte count by two
        // because we're creating an array that holds two 16-bit (two-byte) values
        let dataLength = data.length / sizeof(UInt16)
        var dataArray = [UInt16](count:dataLength, repeatedValue: 0)
        data.getBytes(&dataArray, length: dataLength * sizeof(Int16))

        for i in 0 ..< dataLength {
            let nextInt:UInt16 = dataArray[i]
            print("next int: \(nextInt)")
        }

        let rawAmbientTemp:UInt16 = dataArray[Device.SensorDataIndexTempAmbient]
        let ambientTempC = Double(rawAmbientTemp) / 128.0
        let ambientTempF = convertCelciusToFahrenheit(ambientTempC)
        print("*** AMBIENT TEMPERATURE SENSOR (C/F): \(ambientTempC), \(ambientTempF)");

        // Device also retrieves an infrared temperature sensor value, which we don't use in this demo.
        // However, for instructional purposes, here's how to get at it to compare to the ambient temperature:
        let rawInfraredTemp:UInt16 = dataArray[Device.SensorDataIndexTempInfrared]
        let infraredTempC = Double(rawInfraredTemp) / 128.0
        let infraredTempF = convertCelciusToFahrenheit(infraredTempC)
        print("*** INFRARED TEMPERATURE SENSOR (C/F): \(infraredTempC), \(infraredTempF)");
        
        let temp = Int(ambientTempF)
        lastTemperature = temp
        print("*** LAST TEMPERATURE CAPTURED: \(lastTemperature)° F")
        
        if UIApplication.sharedApplication().applicationState == .Active {
            updateTemperatureDisplay()
        }
    }
    
    func calculateRelativeHumidity(rawH:UInt16) -> Double {
        // clear status bits [1..0]
        let clearedH = rawH & ~0x003
        
        //-- calculate relative humidity [%RH] --
        // RH= -6 + 125 * SRH/2^16
        let relativeHumidity:Double = -6.0 + 125.0/65536 * Double(clearedH)
        return relativeHumidity
    }
    
    func calculateHumidityTemperature(rawT:UInt16) -> Double {
        //-- calculate temperature [deg C] --
        let temp = -46.85 + 175.72/65536 * Double(rawT);
        return temp;
    }
    
}
